// Local fake for external HTTP providers (PR-088): Telegram, free SMS, and
// Nusakit-shaped endpoints with per-service chaos modes, over real sockets
// (real timeouts/aborts, no mocks). CI never touches a real provider: point
// TELEGRAM_*/FREE_SMS_*/NUSAKIT_* at this server with NUSAKIT_ALLOWLIST
// including 127.0.0.1. Usage from shell:
//   node tests/lib/fake_provider.mjs --port 0   (prints URL, serves forever)
// or import { startFakeProvider } from tests/lib/fake_provider.mjs.
import http from 'node:http';

// Modes: ok | http400 | http429 | http500 | malformed | timeout.
// 'down' is simulated by close() (connection refused).
const VALID = new Set(['ok', 'http400', 'http429', 'http500', 'malformed', 'timeout']);

export function startFakeProvider({ port = 0 } = {}) {
  const modes = { telegram: 'ok', sms: 'ok', nik: 'ok' };
  const requests = [];
  const pending = new Set();

  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://x');
    // Control plane for the shell harness (never a provider route).
    if (url.pathname === '/__control' && req.method === 'POST') {
      let body = '';
      req.on('data', (c) => {
        body += c;
      });
      req.on('end', () => {
        try {
          const { service, mode } = JSON.parse(body);
          if (!modes[service] || !VALID.has(mode)) throw new Error('bad control');
          modes[service] = mode;
          res.end('{}');
        } catch {
          res.statusCode = 400;
          res.end('{}');
        }
      });
      return;
    }
    if (url.pathname === '/__calls' && req.method === 'GET') {
      const service = url.searchParams.get('service');
      const rows = requests.filter((r) => !service || r.service === service);
      res.setHeader('content-type', 'application/json');
      res.end(JSON.stringify({ count: rows.length, requests: rows }));
      return;
    }
    let service = null;
    if (url.pathname.startsWith('/telegram/')) service = 'telegram';
    else if (url.pathname === '/sms/send') service = 'sms';
    else if (url.pathname === '/nik/verify') service = 'nik';
    if (!service || req.method !== 'POST') {
      res.statusCode = 404;
      res.end('{}');
      return;
    }
    let body = '';
    req.on('data', (c) => {
      body += c;
    });
    req.on('end', () => {
      requests.push({ service, idempotencyKey: req.headers['idempotency-key'] ?? null, body });
      const mode = modes[service];
      if (mode === 'timeout') {
        // Never respond: the client's AbortSignal fires. Track the socket so
        // close() can destroy it during teardown.
        pending.add(res);
        req.socket.on('close', () => pending.delete(res));
        return;
      }
      if (mode === 'http400' || mode === 'http429' || mode === 'http500') {
        res.statusCode = Number(mode.slice(4));
        res.end('{}');
        return;
      }
      if (mode === 'malformed') {
        res.setHeader('content-type', 'application/json');
        res.end('{not json');
        return;
      }
      res.setHeader('content-type', 'application/json');
      if (service === 'telegram') res.end(JSON.stringify({ ok: true, result: { message_id: 1 } }));
      else if (service === 'sms') res.end(JSON.stringify({ ok: true }));
      else res.end(JSON.stringify({ verdict: 'match' }));
    });
  });

  return new Promise((resolve) => {
    server.listen(port, '127.0.0.1', () => {
      const { port: bound } = server.address();
      resolve({
        url: `http://127.0.0.1:${bound}`,
        set(service, mode) {
          if (!modes[service]) throw new Error(`unknown service '${service}'`);
          if (!VALID.has(mode)) throw new Error(`unknown mode '${mode}'`);
          modes[service] = mode;
        },
        calls(service) {
          return requests.filter((r) => r.service === service).length;
        },
        requests,
        async close() {
          for (const res of pending) res.destroy();
          await new Promise((r) => server.close(r));
        },
      });
    });
  });
}

// CLI: serve forever, print the base URL on stdout for the shell harness.
const cliPort = Number((process.argv[2] === '--port' && process.argv[3]) || 0);
startFakeProvider({ port: cliPort }).then((fake) => {
  console.log(fake.url);
});
