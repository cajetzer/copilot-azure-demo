#!/usr/bin/env node
/**
 * Frontend Web App for Azure troubleshooting demo
 * Serves a simple HTML page that calls the backend API
 */

const http = require('http');

const PORT = process.env.PORT || 3000;
const API_URL = process.env.API_URL || 'http://localhost:3001';

const server = http.createServer((req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle health check
  if (req.url === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', service: 'frontend' }));
    return;
  }

  // Serve root page
  if (req.url === '/' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Azure Troubleshooting Demo</title>
        <style>
          body { font-family: sans-serif; margin: 40px; background: #f5f5f5; }
          .container { max-width: 600px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          h1 { color: #0078d4; }
          .status { padding: 10px; margin: 10px 0; border-radius: 4px; }
          .ok { background: #d4edda; color: #155724; }
          .error { background: #f8d7da; color: #721c24; }
          button { background: #0078d4; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; margin: 5px; }
          button:hover { background: #005a9e; }
          .response { background: #f0f0f0; padding: 10px; margin: 10px 0; border-radius: 4px; font-family: monospace; white-space: pre-wrap; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>🔧 Azure Troubleshooting Demo</h1>
          <p>Frontend service running on port ${PORT}</p>
          <p>Backend API: <code>${API_URL}</code></p>
          
          <div id="status"></div>
          
          <h2>API Tests</h2>
          <button onclick="callHealthCheck()">Health Check (Frontend)</button>
          <button onclick="callBackend()">Call Backend</button>
          <button onclick="callMetadata()">Get Metadata</button>
          
          <h2>Response</h2>
          <div id="response" class="response">Ready for requests...</div>
        </div>

        <script>
          function updateResponse(text, isError = false) {
            const el = document.getElementById('response');
            el.textContent = text;
            el.className = 'response ' + (isError ? 'error' : 'ok');
          }

          async function callHealthCheck() {
            try {
              const res = await fetch('/health');
              const data = await res.json();
              updateResponse(JSON.stringify(data, null, 2));
            } catch (e) {
              updateResponse('Error: ' + e.message, true);
            }
          }

          async function callBackend() {
            try {
              const res = await fetch('${API_URL}/api/health', { 
                method: 'GET',
                headers: { 'Accept': 'application/json' }
              });
              const data = await res.json();
              updateResponse(JSON.stringify(data, null, 2), !res.ok);
            } catch (e) {
              updateResponse('Error calling backend: ' + e.message, true);
            }
          }

          async function callMetadata() {
            try {
              const res = await fetch('${API_URL}/api/metadata', { 
                method: 'GET',
                headers: { 'Accept': 'application/json' }
              });
              const data = await res.json();
              updateResponse(JSON.stringify(data, null, 2), !res.ok);
            } catch (e) {
              updateResponse('Error: ' + e.message, true);
            }
          }

          // Auto-check frontend health on load
          window.addEventListener('load', callHealthCheck);
        </script>
      </body>
      </html>
    `);
    return;
  }

  // 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not Found', path: req.url }));
});

server.listen(PORT, () => {
  console.log(`[Frontend] Listening on http://0.0.0.0:${PORT}`);
  console.log(`[Frontend] Backend API at ${API_URL}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[Frontend] Shutting down gracefully...');
  server.close(() => {
    console.log('[Frontend] Closed');
    process.exit(0);
  });
});
