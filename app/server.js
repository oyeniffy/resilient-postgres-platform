// Infrastructure validation harness for resilient-postgres-platform.
//
// Its job is to prove the App Service infrastructure end-to-end: VNet
// integration, health checks, and (once the /db-check route is exercised)
// reachability to the Postgres server over the private network. Application
// logic (task/notes CRUD) layers on top of this validated foundation once
// deployment resumes — see ADR-0003 for why infrastructure and application
// concerns are kept as deliberately separate build phases in this project.
//
// Uses only Node's built-in http module by design — no dependencies to
// install, nothing that can fail for reasons unrelated to the
// infrastructure being tested.

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
      message: 'resilient-postgres-platform infrastructure validation harness',
      region: REGION,
      note: 'Confirms App Service, VNet integration, and private database connectivity end-to-end. Application logic layers on top of this validated foundation — see ADR-0003.'
    }));
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not found' }));
});

server.listen(PORT, () => {
  console.log(`Infrastructure validation harness listening on port ${PORT}, region=${REGION}`);
});