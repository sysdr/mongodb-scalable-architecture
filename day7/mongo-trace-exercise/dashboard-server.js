/**
 * Dashboard for MongoDB Trace Exercise.
 * Serves trace metrics (from metrics.json) and live MongoDB serverStatus.
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const { MongoClient } = require('mongodb');

const PORT = process.env.DASHBOARD_PORT || 3000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://traceuser:tracepass@localhost:27017';
const METRICS_FILE = path.join(__dirname, 'metrics.json');
let client = null;

function readTraceMetrics() {
  try {
    const raw = fs.readFileSync(METRICS_FILE, 'utf8');
    return JSON.parse(raw);
  } catch (e) {
    return null;
  }
}

async function getMongoMetrics() {
  try {
    if (!client) client = new MongoClient(MONGO_URI);
    await client.connect();
    const status = await client.db().admin().command({ serverStatus: 1 });
    const docCount = await client.db('tracedb').collection('testcollection').countDocuments().catch(() => 0);
    const opcounters = status.opcounters || {};
    const connections = status.connections || {};
    return {
      ok: true,
      docCount,
      opcounters: {
        insert: Number(opcounters.insert) || 0,
        query: Number(opcounters.query) || 0,
        update: Number(opcounters.update) || 0,
        delete: Number(opcounters.delete) || 0,
        command: Number(opcounters.command) || 0,
      },
      connections: {
        current: Number(connections.current) || 0,
        available: Number(connections.available) || 0,
        totalCreated: Number(connections.totalCreated) || 0,
      },
    };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

function runScript(action, cwd, timeoutMs, cb) {
  const allowed = { demo: 'demo.sh', start: 'start.sh', tests: 'run_tests.sh' };
  const script = allowed[action];
  if (!script) return cb(new Error('Invalid action'));
  const scriptPath = path.join(cwd, script);
  execFile('bash', [scriptPath], { cwd, timeout: timeoutMs, maxBuffer: 2 * 1024 * 1024 }, (err, stdout, stderr) => {
    const out = (stdout || '') + (stderr ? '\n' + stderr : '');
    cb(null, { ok: !err, output: out.trim() || (err ? err.message : 'Done.'), code: err ? (err.code || 1) : 0 });
  });
}

const server = http.createServer(async (req, res) => {
  const pathname = (req.url || '').split('?')[0];

  if (pathname === '/favicon.ico') {
    res.statusCode = 204;
    res.end();
    return;
  }

  if (pathname === '/api/metrics') {
    const trace = readTraceMetrics();
    const mongo = await getMongoMetrics();
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ trace, mongo, lastUpdated: new Date().toISOString() }));
    return;
  }

  if (req.method === 'POST' && pathname === '/api/run') {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
      let action;
      try { action = JSON.parse(body || '{}').action; } catch (e) { action = null; }
      if (!action || !['demo', 'start', 'tests'].includes(action)) {
        res.statusCode = 400;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ ok: false, output: 'Invalid action. Use demo, start, or tests.' }));
        return;
      }
      const timeoutMs = action === 'start' ? 120000 : 60000;
      runScript(action, __dirname, timeoutMs, (err, result) => {
        if (err) {
          res.statusCode = 500;
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ ok: false, output: err.message }));
          return;
        }
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(result));
      });
    });
    return;
  }

  if (pathname === '/' || pathname === '/index.html') {
    res.setHeader('Content-Type', 'text/html');
    res.end(fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8'));
    return;
  }

  res.statusCode = 404;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({ ok: false, output: 'Not found: ' + pathname }));
});

server.listen(PORT, () => {
  console.log('Dashboard http://localhost:' + PORT);
  console.log('Routes: GET /, GET /api/metrics, POST /api/run');
});
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
