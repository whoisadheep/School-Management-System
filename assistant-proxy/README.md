Assistant Proxy
================

This lightweight Express server holds the Gemini API key and proxies assistant requests from the Flutter app. It performs per-installation (license key) rate limiting and delegates conversation turns to the Gemini API.

Quick start (local):

1. Copy `.env.example` to `.env` and add your `GEMINI_API_KEY`.

2. Install dependencies:

```bash
cd assistant-proxy
npm install
```

3. Run the server:

```bash
npm run start
```

API
---

POST /assistant/query
Body (JSON):
- `schema`: string — the database schema (from client)
- `userQuestion`: string — the user's prompt
- `conversationHistory`: array — prior conversation messages (optional)
- `installationKey`: string — the per-installation license key used for rate limiting
- `functionResponses`: array — (optional) function call results from the client for tool-calls

Response (JSON):
- `final`: boolean — true if the assistant returned final text
- `text`: string — assistant text when `final` is true
- `functionCalls`: array — list of function calls the proxy requests the client to execute locally (when `final` is false)
- `conversationHistory`: array — updated conversation history to continue the dialog

Notes
-----
- This example uses an in-memory simple counter for daily limits. For production, use Redis or a persistent store.
- Deploy to Railway or similar services by setting environment variables in the project dashboard.
