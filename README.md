# 📝 Docs Suggester AI (DocxAI)

> **Now with Native ChatGPT Panel Support! 🚀**

AI-powered document review agent for consulting deliverables. Works seamlessly inside **ChatGPT** via a custom interactive panel, or as a standalone REST API.

![Demo UI](demo_ui.png)

---

## ✨ Features

- **🎨 Interactive Widget**: Upload and edit documents directly inside ChatGPT (no external file hosts needed).
- **🧠 GPT-4o Integration**: Uses the latest AI models for high-quality consulting feedback.
- **🔒 Secure Connectivity**: Dynamically injects secure Ngrok tunnels for safe API communication.
- **⚡️ Smart Editing**: 
  - Detects tone issues (e.g., "don't" → "do not")
  - Flag long, complex paragraphs
  - Rewrite text for clarity and impact
- **⬇️ Direct Download**: Get your modified `.docx` file instantly from the panel.

---

## 🚀 Quick Start

### Prerequisites
- Python 3.10+
- Node.js & npm
- `uv` (recommended) or `pip`

### 1. Installation

**Backend setup:**
```bash
cd backend
uv pip install -r requirements.txt
```

**Frontend setup:**
```bash
cd frontend
npm install
npm run build
```

**Widget Compilation:**
This connects the frontend to the backend logic.
```bash
# From project root
python3 inline_assets.py
```

### 2. Running the Server

You need two things running: the **backend server** and **ngrok** tunnel.

**Start the Backend:**
```bash
cd backend
python server.py
# Runs on http://localhost:8787
```

**Start Ngrok:**
```bash
ngrok http 8787
```
*Note the HTTPS URL provided by ngrok (e.g., `https://xxxx.ngrok-free.app`).*

---

## 🤖 Usage: ChatGPT Integration

This is the primary way to use the agent.

1.  **Configure ChatGPT**:
    -   Go to **GPT Builder** (`@Docs Suggester AI`).
    -   Add Action -> Import from URL: `https://your-ngrok-url.ngrok-free.app/sse`
    
2.  **Start Editing**:
    -   Just type: **"Open DocxAI Panel"**
    -   The interactive widget will appear above the chat.
    
3.  **Workflow**:
    -   **Upload**: Click the file input in the panel.
    -   **Analyze**: Type "Make this more professional" and click **Upload & Analyze**.
    -   **Review**: Select the suggestions you like.
    -   **Apply**: Click **Apply Changes**.
    -   **Download**: Click the download button to get your new file.

---

## 🛠️ Architecture: The "Proper" Solution

We implemented a robust **Dynamic Host Injection** architecture to solve the "localhost in cloud" problem.



1.  **Self-Contained Frontend**: The React widget is built into a single `index.html` file using `inline_assets.py`.
2.  **Runtime Injection**: When you request the panel, the backend updates the widget code on-the-fly with the current secure Ngrok URL.
3.  **Direct Communication**: The widget talks directly to your backend, bypassing ChatGPT's restrictive file handling limits.

---

## ☁️ Deployment: Azure Multi-Container Strategy

For production-grade environments, the project supports a **Multi-Container Azure App Service** deployment. This methodology ensures scalability and a unified entry point.

### Deployment Methodology:
1.  **Containerization**: Three distinct services are orchestrated:
    -   **MCP Backend**: FastAPI server handling logic and MCP protocol.
    -   **React Frontend**: Static assets served via a dedicated web server.
    -   **Nginx Gateway**: A unified reverse-proxy that routes traffic to the correct internal containers and manages SSE (Server-Sent Events) headers.
2.  **Architecture**: Deployment is performed via Azure Container Registry (ACR) and managed through Docker Compose configurations on Azure App Service.
3.  **Cross-Platform Builds**: Images are built using `linux/amd64` to ensure compatibility with Azure infrastructure.
4.  **Security**: Environment variables (like `OPENAI_API_KEY`) and registry credentials are managed securely through Azure's Application Settings.

---

## 🔌 API Reference & Documentation

The backend is built with **FastAPI**, providing automatic, interactive documentation.

### Interactive Swagger UI
When running the application (locally or on Azure), you can access the interactive Swagger documentation at:
-   **Endpoint**: `/api/docs`
-   **Features**: Test endpoints, view request/response schemas, and explore the API structure.

### Standard REST Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/upload` | Upload `.docx` file |
| `POST` | `/api/analyze` | Get AI suggestions |
| `POST` | `/api/apply` | Apply selected edits |
| `GET` | `/api/download/{id}` | Download result |

---

## 📂 Project Structure

```
.
├── backend/
│   ├── server.py           # FastAPI MCP Server + Injection Logic
│   └── requirements.txt    # Python dependencies
├── frontend/
│   ├── src/App.jsx         # React Widget Logic
│   └── dist/index.html     # Compiled Widget
├── inline_assets.py        # Build script for widget
├── deploy-azure.sh         # Automated Azure deployment script
├── docker-compose-azure.yml # Azure orchestration config
└── nginx.conf              # Gateway proxy configuration
```

## License

MIT
