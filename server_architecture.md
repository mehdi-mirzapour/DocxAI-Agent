# 🏗️ Server Architecture Explained: `backend/server.py`

This document breaks down the internal workings of `server.py`, the core brain of the DocxAI agent.

## 1. High-Level Overview

`server.py` is a hybrid server that performs two roles simultaneously:
1.  **MCP Server**: It talks to ChatGPT via the Model Context Protocol (MCP) using Server-Sent Events (SSE).
2.  **REST API**: It serves standard HTTP endpoints (POST/GET) that the frontend widget talks to directly.

---

## 2. Key Components Breakdown

### A. Initialization & Configuration
*   **Imports**: Uses `mcp.server`, `starlette` (web server), `openai` (AI logic), and `python-docx` (Word manipulation).
*   **Server Setup**: Initializes `app = Server("docs-suggester-ai")` which manages the MCP protocol state.
*   **Storage**: Creates an `uploads/` directory and uses in-memory dictionaries (`documents`, `suggestions_store`) to track active sessions.

### B. Core Application Logic (The "Business Logic")
These functions do the actual work, independent of *how* they are called (MCP or API).

*   **`extract_document_metadata(doc_path)`**:
    *   Opens a `.docx` file using `python-docx`.
    *   Counts words and paragraphs to generate a summary.
*   **`generate_suggestions(doc_path, request)`**:
    *   Reads the document text.
    *   Sends chunks of text to **GPT-4o** via the OpenAI API.
    *   Parses the JSON response to extract specific editing suggestions.
    *   *Fallback*: Includes a rule-based system if the OpenAI key is missing.
*   **`apply_changes_to_document(...)`**:
    *   Takes a list of approved suggestion IDs.
    *   Modifies the original `.docx` file in place (or creates a copy).
    *   Saves the result as `_modified.docx`.
*   **`get_public_url()`**:
    *   **Crucial for the "Proper Solution"**.
    *   Queries `http://127.0.0.1:4040/api/tunnels` (Ngrok's local API).
    *   Returns the active HTTPS public URL (e.g., `https://xyz.ngrok.app`).

### C. MCP Integration (Talking to ChatGPT)
This section defines what ChatGPT "sees".

*   **Resources (`@app.list_resources`, `@app.read_resource`)**:
    *   Exposes the **Widget HTML** (`ui://widget/document-editor.html`).
    *   **Dynamic Injection**: Before serving the HTML, it injects the script `<script>window.DOCX_API_URL = "..."</script>`. This tells the frontend where to connect.
*   **Tools (`@app.list_tools`, `@app.call_tool`)**:
    *   **`open_docxai_panel`**: The trigger tool. Returns text instructing the user to look at the panel.
    *   **`upload_document`**: Handles file intake (mostly legacy/fallback now, as widget uploads directly).
    *   **`analyze_document`**: Wraps `generate_suggestions`.
    *   **`apply_changes`**: Wraps `apply_changes_to_document`.
*   **Prompts (`@app.list_prompts`)**:
    *   Defines `open_panel` to give ChatGPT a canonical "shortcut" to open the tool.

### D. REST API Endpoints (Talking to the Widget)
Starlette routes that handle traffic from the React frontend.

*   **`POST /api/upload`**: Receives a `multipart/form-data` file upload, saves it, and returns a UUID.
*   **`POST /api/analyze`**: Receives a UUID and query, runs GPT-4o, returns JSON suggestions.
*   **`POST /api/apply`**: Receives selected suggestion IDs, applies them, returns a download link.
*   **`GET /api/download/{filename}`**: Serves the binary `.docx` file for download.

### E. The Transport Layer (Starlette + SSE)
This connects everything to the network.

*   **`SseServerTransport("/sse/messages")`**: The specific MCP class that manages the persistent connection with ChatGPT.
*   **Route Mounting**:
    *   `/sse`: Handshake endpoint.
    *   `/sse/messages`: Message exchange endpoint.
    *   `/api`: REST API mount.

---

## 3. Data Flow Example

1.  **User** says "Open DocxAI Panel".
2.  **ChatGPT** calls `open_docxai_panel` tool.
3.  **MCP Server** responds "Panel Open" and triggers the UI.
4.  **Backend** reads `index.html`, fetches Ngrok URL, injects it, and sends HTML to ChatGPT.
5.  **User** uploads file in the Widget.
6.  **Widget** (in browser) POSTs file directly to `https://ngrok-url/api/upload`.
7.  **Backend** processes file and returns ID.
