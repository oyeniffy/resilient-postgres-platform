// Minimal placeholder app for resilient-postgres-platform.
//
// Deliberately does nothing interesting yet. Its only job right now is to
// prove the App Service infrastructure works: VNet integration, health
// checks, and (once the /db-check route is exercised) reachability to the
// Postgres server over the private network. Real task/notes CRUD logic
// gets added once this is confirmed working end-to-end — see ADR-0003 for
// why infrastructure and application concerns are kept deliberately
// separate in this project.
//
// Uses only Node's built-in http module — no dependencies to install,
// nothing that can fail for reasons unrelated to the infrastructure being
// tested.

const http = require('http');

const PORT = process.env.PORT || 8080;
const REGION = process.env.REGION_NAME || 'unknown';

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', region: REGION }));
    return;
  }

  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      message: 'resilient-postgres-platform placeholder app',
      region: REGION,
      note: 'Real task/notes API not yet implemented — this confirms the App Service, VNet integration, and health checks are working.'
    }));
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not found' }));
});

server.listen(PORT, () => {
  console.log(`Placeholder app listening on port ${PORT}, region=${REGION}`);
});
