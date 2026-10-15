import { test } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import request from 'supertest';
import { buildApp } from '../src/app.js';
import { resetMetrics, recordRequest, metricsText, setGauge, pushMetrics, startMetricsExporter } from '../src/observability.js';
import { getVerificationCode, seedUser } from './support.js';

test('metricsText renders recorded counters', () => {
  resetMetrics();
  recordRequest({ method: 'GET', route: '/health', status: 200 });
  recordRequest({ method: 'GET', route: '/health', status: 200 });
  const text = metricsText();
  assert.match(text, /gateway_requests_total\{method="GET",route="\/health",status="200"\} 2/);
});

test('metricsText renders gauges', () => {
  resetMetrics();
  setGauge('gateway_cobol_pool_workers', 3);
  const text = metricsText();
  assert.match(text, /# TYPE gateway_cobol_pool_workers gauge/);
  assert.match(text, /gateway_cobol_pool_workers 3/);
});

test('a request is logged with an id, route and latency', async () => {
  resetMetrics();
  const lines = [];
  const app = buildApp({ logger: (line) => lines.push(line) });
  const res = await request(app).get('/health');
  assert.equal(res.status, 200);
  assert.ok(res.headers['x-request-id']);

  const line = lines.find((l) => l.event === 'http_request');
  assert.ok(line, 'request line emitted');
  assert.equal(line.method, 'GET');
  assert.equal(line.route, '/health');
  assert.equal(line.status, 200);
  assert.equal(typeof line.durationMs, 'number');
  // The raw path (which may contain an email) is not logged.
  assert.equal(line.path, undefined);
});

test('/metrics requires a token', async () => {
  const app = buildApp();
  const denied = await request(app).get('/metrics');
  assert.equal(denied.status, 401);
});

test('/metrics is admin-only', async (t) => {
  resetMetrics();
  const app = buildApp();
  const em = `obs_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Obs User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const login = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });

  await request(app).get('/health');
  // A plain user is refused.
  assert.equal((await request(app).get('/metrics').set('Authorization', `Bearer ${login.body.token}`)).status, 403);

  // A SUPER_ADMIN sees the counters.
  const admin = `obs_admin_${Date.now()}@test.com`;
  if (!seedUser(admin, 'SUPER_ADMIN')) return t.skip('mysql client unavailable to seed a SUPER_ADMIN');
  const adminToken = (await request(app).post('/auth/login').send({ email: admin, password: 'secret123' })).body.token;
  const m = await request(app).get('/metrics').set('Authorization', `Bearer ${adminToken}`);
  assert.equal(m.status, 200);
  assert.match(m.text, /gateway_requests_total/);
  assert.match(m.text, /route="\/health"/);
});

test('pushMetrics posts the counters to a collector', async () => {
  const received = [];
  const server = http.createServer((req, res) => {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => { received.push(body); res.statusCode = 202; res.end(); });
  });
  await new Promise((resolve) => server.listen(0, resolve));
  const { port } = server.address();

  resetMetrics();
  recordRequest({ method: 'GET', route: '/health', status: 200 });
  const status = await pushMetrics(`http://127.0.0.1:${port}/metrics`);
  assert.equal(status, 202);
  assert.match(received[0], /gateway_requests_total\{method="GET",route="\/health",status="200"\} 1/);

  await new Promise((resolve) => server.close(resolve));
});

test('the exporter pushes on an interval and survives a failing collector', async () => {
  const hits = [];
  const server = http.createServer((_req, res) => { hits.push(1); res.statusCode = 200; res.end(); });
  await new Promise((resolve) => server.listen(0, resolve));
  const { port } = server.address();

  const stop = startMetricsExporter({ url: `http://127.0.0.1:${port}/sink`, intervalMs: 20 });
  await new Promise((resolve) => setTimeout(resolve, 80));
  stop();
  await new Promise((resolve) => server.close(resolve));
  assert.ok(hits.length >= 2, `expected repeated pushes, got ${hits.length}`);

  // A failing collector must not throw out of the exporter.
  const stopBad = startMetricsExporter({ url: 'http://127.0.0.1:1/nope', intervalMs: 10 });
  await new Promise((resolve) => setTimeout(resolve, 30));
  stopBad();
});
