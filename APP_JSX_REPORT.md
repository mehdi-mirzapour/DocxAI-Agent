# Analysis of App.jsx: Frontend vs. ChatGPT Integration

This report breaks down the `App.jsx` file into its core functional areas: standard Frontend React logic and the specific integration points with ChatGPT (OpenAI bridge).

## 1. Frontend & Local UI Logic
The majority of the file is dedicated to standard React state management, UI rendering, and "Standalone Mode" functionality (where the app runs independently of ChatGPT).

### Key Components:
- **State Management (Lines 7-20)**: Uses `useState` for managing document IDs, suggestions, upload progress, and UI status (`idle`, `uploading`, `analyzing`, `completed`, `error`).
- **File Upload & Analysis (Lines 72-143)**: 
  - `handleFileUpload`: Manages the local `multipart/form-data` upload to the backend.
  - Communicates with `/api/upload` and `/api/analyze`.
- **Suggestion Selection (Lines 145-155)**: `toggleSuggestion` handles the checkboxes for which AI edits to apply.
- **Applying Changes (Lines 157-187)**: `handleApplyChanges` sends the selected suggestions to `/api/apply` and generates a download URL.
- **Rendering Logic (Lines 189-321)**:
  - **Empty State**: Shows the upload form when no suggestions are present.
  - **Suggestions List**: Displays original vs. suggested text for each edit.
  - **Action Bar**: Fixed bottom bar with "Apply" and "Download" buttons.

## 2. ChatGPT / OpenAI Integration
These parts are specific to how the application communicates with the ChatGPT interface when running as a plugin or custom tool.

### Key Integration Points:
- **`API_BASE` (Line 4)**: 
  - `window.DOCX_API_URL` is used if available. This allows the ChatGPT environment to dynamically set the backend location (e.g., an ngrok tunnel).
- **Standalone Detection (Lines 21-24)**:
  - `setIsStandalone(!window.openai)`: Checks for the existence of the `window.openai` object to determine if it's running inside a ChatGPT environment.
- **Initial Data Fetch (Lines 26-35)**:
  - `window.openai?.toolOutput`: Directly reads results from ChatGPT's internal tool output. This allows the app to load with data already processed by the AI.
- **Live Event Synchronization (Lines 37-64)**:
  - `window.addEventListener('openai:set_globals', ...)`: Listens for custom events from the ChatGPT bridge. When ChatGPT's tools update data (like a new `doc_id` or `suggestions`), this listener synchronizes the React state automatically without a page refresh.

## Summary Table

| Feature | Code Part | Responsibility |
| :--- | :--- | :--- |
| **UI/UX** | Lines 189-321 | Rendering the editor interface and lists. |
| **Backend API** | Lines 72-187 | Standard fetch calls to the local Python server. |
| **ChatGPT Bridge** | Lines 21-64 | Listening to `window.openai` and event updates. |
| **Env Injection** | Line 4 | Handling dynamic URLs from the ChatGPT host. |
