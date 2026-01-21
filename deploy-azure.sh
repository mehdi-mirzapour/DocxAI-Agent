#!/bin/bash
set -e

# --- Configuration ---
RESOURCE_GROUP="docxai-rg"
LOCATION="westeurope"
ACR_NAME="docxaicr"
APP_SERVICE_PLAN="docxai-plan"
WEB_APP_NAME="docxai-app"

# Load OpenAI key from .env if available
if [ -f .env ]; then
    export $(grep OPENAI_API_KEY .env | xargs)
fi

if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ ERROR: OPENAI_API_KEY is not set. Please set it in your .env file or environment."
    exit 1
fi

echo "🚀 Starting DocxAI Automated Azure Deployment..."

# 1. Infrastructure Setup
echo "🏗️ Checking Infrastructure (RG & ACR)..."
if ! az group show --name $RESOURCE_GROUP >/dev/null 2>&1; then
    echo "   -> Creating Resource Group: $RESOURCE_GROUP"
    az group create --name $RESOURCE_GROUP --location $LOCATION
fi

if ! az acr show --name $ACR_NAME >/dev/null 2>&1; then
    echo "   -> Creating Container Registry: $ACR_NAME"
    az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true
else
    echo "   -> Ensuring ACR Admin is enabled"
    az acr update --name $ACR_NAME --admin-enabled true
fi

# 2. ACR Login
echo "🔐 Logging into ACR..."
az acr login --name $ACR_NAME

# 3. Build & Push Images
echo "🔨 Building and Pushing Docker Images (Platform: linux/amd64)..."
ACR_URL="$ACR_NAME.azurecr.io"

echo "   -> Building MCP..."
docker build --platform linux/amd64 -f Dockerfile.mcp -t $ACR_URL/docxai-mcp:latest .
docker push $ACR_URL/docxai-mcp:latest

echo "   -> Building Frontend..."
docker build --platform linux/amd64 -f Dockerfile.frontend -t $ACR_URL/docxai-frontend:latest .
docker push $ACR_URL/docxai-frontend:latest

echo "   -> Building Nginx..."
docker build --platform linux/amd64 -f Dockerfile.nginx -t $ACR_URL/docxai-nginx:latest .
docker push $ACR_URL/docxai-nginx:latest

# 5. Configure Settings (CRITICAL: Must be done BEFORE setting container config)
echo "⚙️ Configuring Application Settings..."
ACR_PASS=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

if [ -z "$ACR_PASS" ]; then
    echo "❌ ERROR: Failed to retrieve ACR password."
    exit 1
fi

az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $WEB_APP_NAME \
  --settings \
  DOCKER_REGISTRY_SERVER_URL="https://$ACR_URL" \
  DOCKER_REGISTRY_SERVER_USERNAME="$ACR_NAME" \
  DOCKER_REGISTRY_SERVER_PASSWORD="$ACR_PASS" \
  DOCKER_REGISTRY="$ACR_URL" \
  OPENAI_API_KEY="$OPENAI_API_KEY" \
  WEBSITES_PORT=80 \
  NGROK_URL="https://$WEB_APP_NAME.azurewebsites.net" \
  DOCKER_ENABLE_CI=true > /dev/null

echo "⏳ Waiting for settings to propagate..."
sleep 10

# 6. Process Docker Compose file (Azure doesn't support variable interpolation in the file itself)
echo "📝 Preparing Docker Compose configuration..."
export DOCKER_REGISTRY="$ACR_URL"
export OPENAI_API_KEY="$OPENAI_API_KEY"
envsubst < docker-compose-azure.yml > docker-compose-azure.processed.yml

# 4. App Service Setup
echo "🌐 Setting up App Service..."
if ! az appservice plan show --name $APP_SERVICE_PLAN --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
    echo "   -> Creating App Service Plan: $APP_SERVICE_PLAN"
    az appservice plan create --name $APP_SERVICE_PLAN --resource-group $RESOURCE_GROUP --sku B1 --is-linux
fi

if az webapp show --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
    echo "   -> Updating existing Web App configuration..."
    az webapp config container set \
      --resource-group $RESOURCE_GROUP \
      --name $WEB_APP_NAME \
      --multicontainer-config-type compose \
      --multicontainer-config-file docker-compose-azure.processed.yml
else
    echo "   -> Creating new Web App: $WEB_APP_NAME"
    az webapp create \
      --resource-group $RESOURCE_GROUP \
      --plan $APP_SERVICE_PLAN \
      --name $WEB_APP_NAME \
      --multicontainer-config-type compose \
      --multicontainer-config-file docker-compose-azure.processed.yml
fi

rm docker-compose-azure.processed.yml

echo "⏳ Waiting for App Service to restart and pull images..."
# Trigger a restart to be sure
az webapp restart --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP

echo "✅ Deployment Complete!"
echo "📍 App URL: https://$WEB_APP_NAME.azurewebsites.net"
echo "👉 Note: It may take 2-5 minutes for all containers to start up."



