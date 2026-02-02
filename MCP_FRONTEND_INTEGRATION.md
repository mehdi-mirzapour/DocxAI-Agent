# MCP and App.jsx Integration Guide

This document explains how the React frontend (`App.jsx`) interacts with the Model Context Protocol (MCP) server in the Docx-Consulting-AI-Agent project.

## Overview

The integration follows a "Widget" architecture where the MCP server serves the entire frontend application as a resource to the MCP client (e.g., ChatGPT). The communication happens through a combination of dynamic URL injection and the `window.openai` bridge.

---

## 1. The MCP Server as the Host

The Python backend (`backend/server.py`) uses the `mcp` library to define a server. It exposes the frontend as an MCP resource:

- **Resource URI**: `ui://widget/document-editor.html`
- **Source**: `frontend/dist/index.html` (the built React app)

### Dynamic URL Injection
When the MCP server reads the `index.html` file to serve it, it dynamically injects a configuration script into the `<head>`:

```python
# backend/server.py
public_url = get_public_url() # Fetches ngrok or local URL
injection = f'<script>window.DOCX_API_URL = "{public_url}/api";</script>'
widget_html = widget_html.replace("<head>", f"<head>{injection}")
```

This allows the frontend to know the base URL for API calls regardless of where it is being hosted.

---

## 2. App.jsx: Dual-Mode Intelligence

The React application is designed to work in two environments:
1. **Standalone Mode**: Running in a standard browser (e.g., `localhost:5173`).
2. **MCP Mode**: Running inside an MCP client's iframe (e.g., ChatGPT's portal).

### Detection
The app detects its environment by checking for the `window.openai` object:

```javascript
// frontend/src/App.jsx
useEffect(() => {
    setIsStandalone(!window.openai)
}, [])
```

---

## 3. Communication Bridge

### Initial Data Load
When an MCP tool returns a reference to the UI, it can also pass "structured content" or "tool output". `App.jsx` reads this on initialization:

```javascript
// frontend/src/App.jsx
useEffect(() => {
    const initialData = window.openai?.toolOutput
    if (initialData?.doc_id) {
        setDocId(initialData.doc_id)
        setSuggestions(initialData.suggestions)
    }
}, [])
```

### Live Updates
If the MCP client updates its state (e.g., after the AI performs a search or another tool call), the frontend listens for the `openai:set_globals` event to stay in sync:

```javascript
// frontend/src/App.jsx
useEffect(() => {
    const handleSetGlobals = (event) => {
        const globals = event.detail?.globals
        if (globals?.toolOutput) {
            setSuggestions(globals.toolOutput.suggestions)
            // ... update other state
        }
    }
    window.addEventListener('openai:set_globals', handleSetGlobals)
    return () => window.removeEventListener('openai:set_globals', handleSetGlobals)
}, [])
```

---

## 4. API Interaction

In both modes, the frontend communicates with the backend's REST endpoints (`/api/upload`, `/api/analyze`, `/api/apply`) using the injected `API_BASE`:

```javascript
const API_BASE = window.DOCX_API_URL || 'http://localhost:8787/api'

// Example: Applying changes
const response = await fetch(`${API_BASE}/apply`, {
    method: 'POST',
    body: JSON.stringify({ doc_id, suggestion_ids }),
    // ...
})
```

---

## Summary of Interaction Flow

1. **User asks AI** to "Open DocxAI Panel".
2. **AI calls MCP Tool** `open_docxai_panel`.
3. **MCP Server** returns the `ui://widget/document-editor.html` resource.
4. **MCP Client** (ChatGPT) renders the frontend in an iframe.
5. **Frontend** reads `window.DOCX_API_URL` to connect back to the backend.
6. **Frontend** reads `window.openai.toolOutput` to display any initial suggestions.
7. **User interacts** with the React UI to approve/reject edits.
8. **Frontend sends REST requests** to the Python API to save the final document.
