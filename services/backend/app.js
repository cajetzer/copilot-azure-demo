#!/usr/bin/env node
/**
 * Backend API for Azure troubleshooting demo
 * Provides REST endpoints for data queries, health checks, and database operations
 */

const http = require('http');
const url = require('url');

const PORT = process.env.PORT || 3001;
const NODE_ENV = process.env.NODE_ENV || 'production';
const APP_INSIGHTS_KEY = process.env.AZURE_CLIENT_ID || 'N/A';
const SQL_CONNECTION_STRING = process.env.SQL_CONNECTION_STRING || 'Not configured';

// Track request count for demo purposes
let requestCount = 0;
let errorCount = 0;

const server = http.createServer((req, res) => {
  requestCount++;

  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  // Parse request URL
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const query = parsedUrl.query;

  // Log request
  console.log(`[Backend] ${req.method} ${pathname} (request #${requestCount})`);

  // Handle OPTIONS (CORS preflight)
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Health check endpoint
  if (pathname === '/api/health' && req.method === 'GET') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'healthy',
      service: 'backend',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: NODE_ENV,
      requestCount: requestCount,
      errorCount: errorCount
    }));
    return;
  }

  // Metadata endpoint
  if (pathname === '/api/metadata' && req.method === 'GET') {
    res.writeHead(200);
    res.end(JSON.stringify({
      service: 'backend',
      version: '1.0.0',
      environment: NODE_ENV,
      appInsightsKey: APP_INSIGHTS_KEY,
      sqlConfigured: SQL_CONNECTION_STRING !== 'Not configured',
      timestamp: new Date().toISOString()
    }));
    return;
  }

  // Status endpoint with request stats
  if (pathname === '/api/status' && req.method === 'GET') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'operational',
      service: 'backend-api',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      requestCount: requestCount,
      errorCount: errorCount,
      metrics: {
        environment: NODE_ENV,
        node_version: process.version
      }
    }));
    return;
  }

  // Echo endpoint (reflects request info)
  if (pathname === '/api/echo' && req.method === 'GET') {
    res.writeHead(200);
    res.end(JSON.stringify({
      message: 'Echo response from backend',
      query: query,
      timestamp: new Date().toISOString()
    }));
    return;
  }

  // Simulated data endpoint
  if (pathname === '/api/data' && req.method === 'GET') {
    const count = parseInt(query.count || '10', 10);
    const items = Array.from({ length: count }, (_, i) => ({
      id: i + 1,
      name: `Item ${i + 1}`,
      timestamp: new Date().toISOString(),
      status: Math.random() > 0.8 ? 'error' : 'ok'
    }));

    // Count errors
    errorCount += items.filter(x => x.status === 'error').length;

    res.writeHead(200);
    res.end(JSON.stringify({
      items: items,
      count: items.length,
      errors: items.filter(x => x.status === 'error').length
    }));
    return;
  }

  // Database connection test
  if (pathname === '/api/db-test' && req.method === 'GET') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'db_test',
      configured: SQL_CONNECTION_STRING !== 'Not configured',
      message: SQL_CONNECTION_STRING !== 'Not configured' 
        ? 'SQL connection string is configured'
        : 'SQL connection string not configured',
      timestamp: new Date().toISOString()
    }));
    return;
  }

  // 404
  res.writeHead(404);
  errorCount++;
  res.end(JSON.stringify({
    error: 'Not Found',
    path: pathname,
    availableEndpoints: [
      '/api/health',
      '/api/metadata',
      '/api/status',
      '/api/echo?message=test',
      '/api/data?count=10',
      '/api/db-test'
    ]
  }));
});

server.listen(PORT, () => {
  console.log(`[Backend] Listening on http://0.0.0.0:${PORT}`);
  console.log(`[Backend] Node environment: ${NODE_ENV}`);
  console.log(`[Backend] SQL configured: ${SQL_CONNECTION_STRING !== 'Not configured' ? 'Yes' : 'No'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[Backend] Shutting down gracefully...');
  server.close(() => {
    console.log('[Backend] Closed');
    process.exit(0);
  });
});
