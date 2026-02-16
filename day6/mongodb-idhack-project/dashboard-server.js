/**
 * Dashboard server for MongoDB IDHACK project.
 * Runs from project dir. Serves light-theme web UI with project info and real-time metrics.
 */
const http = require('http');
const { MongoClient } = require('mongodb');

const PORT = process.env.DASHBOARD_PORT || 3000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017';
const DB_NAME = 'idhackDB';
const COLLECTION_NAME = 'contentItems';

let client = null;

async function getMetrics() {
  try {
    if (!client) client = new MongoClient(MONGO_URI);
    await client.connect();
    const db = client.db();
    const status = await db.admin().command({ serverStatus: 1 });
    const docCount = await client.db(DB_NAME).collection(COLLECTION_NAME).countDocuments();
    const opcounters = status.opcounters || {};
    const connections = status.connections || {};
    return {
      ok: true,
      docCount,
      opcounters: {
        insert: opcounters.insert != null ? Number(opcounters.insert) : 0,
        query: opcounters.query != null ? Number(opcounters.query) : 0,
        update: opcounters.update != null ? Number(opcounters.update) : 0,
        delete: opcounters.delete != null ? Number(opcounters.delete) : 0,
        getmore: opcounters.getmore != null ? Number(opcounters.getmore) : 0,
        command: opcounters.command != null ? Number(opcounters.command) : 0,
      },
      connections: {
        current: connections.current != null ? connections.current : 0,
        available: connections.available != null ? connections.available : 0,
        totalCreated: connections.totalCreated != null ? connections.totalCreated : 0,
        active: connections.active != null ? connections.active : 0,
      },
      lastUpdated: new Date().toISOString(),
    };
  } catch (err) {
    return { ok: false, error: err.message, lastUpdated: new Date().toISOString() };
  }
}

const HTML_PAGE = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MongoDB IDHACK Dashboard</title>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      margin: 0;
      padding: 24px;
      background: #f5f5f5;
      color: #1a1a1a;
      line-height: 1.5;
    }
    .container { max-width: 960px; margin: 0 auto; }
    h1 {
      font-size: 1.75rem;
      font-weight: 700;
      color: #0f766e;
      margin: 0 0 8px 0;
    }
    .subtitle { color: #525252; margin: 0 0 24px 0; font-size: 0.95rem; }
    .card {
      background: #fff;
      border: 1px solid #e5e5e5;
      border-radius: 8px;
      padding: 20px;
      margin-bottom: 20px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    }
    .card h2 {
      font-size: 1.1rem;
      font-weight: 600;
      color: #171717;
      margin: 0 0 16px 0;
      padding-bottom: 8px;
      border-bottom: 1px solid #e5e5e5;
    }
    .info p { margin: 0 0 12px 0; color: #404040; }
    .info p:last-child { margin-bottom: 0; }
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
      gap: 12px;
    }
    .metric {
      background: #fafafa;
      border: 1px solid #e5e5e5;
      border-radius: 6px;
      padding: 12px;
      text-align: center;
    }
    .metric .label { font-size: 0.75rem; color: #737373; text-transform: uppercase; letter-spacing: 0.02em; margin-bottom: 4px; }
    .metric .value { font-size: 1.25rem; font-weight: 600; color: #0f766e; }
    .footer {
      margin-top: 24px;
      font-size: 0.85rem;
      color: #737373;
    }
    .live-dot {
      display: inline-block;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #22c55e;
      margin-right: 6px;
      animation: pulse 2s ease-in-out infinite;
    }
    .live-dot.error { background: #dc2626; }
    @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.6; } }
  </style>
</head>
<body>
  <div class="container">
    <h1>MongoDB IDHACK Dashboard</h1>
    <p class="subtitle">Point lookups with UUIDv7 — real-time metrics</p>

    <div class="card">
      <h2>About this project</h2>
      <div class="info">
        <p><strong>MongoDB 8.0 IDHACK</strong> demonstrates high-performance point lookups using <strong>UUIDv7</strong> as document <code>_id</code>. UUIDv7 is time-ordered, so inserts and lookups benefit from locality.</p>
        <p><strong>Operations:</strong> The app inserts a large set of documents with UUIDv7 <code>_id</code> into <code>idhackDB.contentItems</code>, then runs random point lookups by <code>_id</code>. Metrics below update in real time as the demo or other workloads run.</p>
      </div>
    </div>

    <div class="card">
      <h2><span class="live-dot" id="liveDot"></span> Live metrics <span id="lastUpdated"></span></h2>
      <div class="metrics-grid" id="metricsGrid"></div>
    </div>

    <div class="footer" id="footer"></div>
  </div>
  <script>
    const grid = document.getElementById('metricsGrid');
    const lastUpdated = document.getElementById('lastUpdated');
    const liveDot = document.getElementById('liveDot');
    const footer = document.getElementById('footer');

    function render(m) {
      if (!m.ok) {
        grid.innerHTML = '<p style="color:#dc2626;">Could not load metrics: ' + (m.error || 'Unknown') + '</p>';
        liveDot.classList.add('error');
        footer.textContent = 'Ensure MongoDB is running and start.sh (or demo) has been run.';
        return;
      }
      liveDot.classList.remove('error');
      const ops = m.opcounters;
      const conn = m.connections;
      grid.innerHTML = [
        { label: 'Documents (contentItems)', value: m.docCount.toLocaleString() },
        { label: 'Insert ops', value: (ops.insert || 0).toLocaleString() },
        { label: 'Query ops', value: (ops.query || 0).toLocaleString() },
        { label: 'Update ops', value: (ops.update || 0).toLocaleString() },
        { label: 'Delete ops', value: (ops.delete || 0).toLocaleString() },
        { label: 'Command ops', value: (ops.command || 0).toLocaleString() },
        { label: 'Connections (current)', value: String(conn.current || 0) },
        { label: 'Connections (available)', value: (conn.available || 0).toLocaleString() },
        { label: 'Connections (total created)', value: (conn.totalCreated || 0).toLocaleString() },
      ].map(function (item) {
        return '<div class="metric"><div class="label">' + item.label + '</div><div class="value">' + item.value + '</div></div>';
      }).join('');
      lastUpdated.textContent = 'Updated ' + (m.lastUpdated ? new Date(m.lastUpdated).toLocaleTimeString() : '');
      footer.textContent = 'Metrics refresh every 3 seconds. Run ./demo.sh or ./start.sh to populate data.';
    }

    function fetchMetrics() {
      fetch('/api/metrics').then(function (r) { return r.json(); }).then(render).catch(function (e) {
        render({ ok: false, error: e.message });
      });
    }

    fetchMetrics();
    setInterval(fetchMetrics, 3000);
  </script>
</body>
</html>
`;

const server = http.createServer(async (req, res) => {
  if (req.url === '/' || req.url === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(HTML_PAGE);
    return;
  }
  if (req.url === '/api/metrics') {
    const data = await getMetrics();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(data));
    return;
  }
  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log('Dashboard server at http://localhost:' + PORT);
});

process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
