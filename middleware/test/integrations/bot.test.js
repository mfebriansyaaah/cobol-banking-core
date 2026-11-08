import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import request from 'supertest';
import { buildApp } from '../../src/app.js';
import { testNamespace, uniqueEmail, cleanupNamespace } from '../support.js';
import { turnstileEnabled, verifyTurnstile } from '../../services/integrations/bot/turnstile.js';
import { resetBreakers } from '../../services/integrations/resilience.js';
import { resetMetrics, metricsText } from '../../src/observability.js';

const okFetch =
  (success = true, codes = []) =>
  () =>
    Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ success, 'error-codes': codes }) });
const withSecret = { secret: 's3cret', timeoutMs: 500 };

test('skipped without secret; missing token rejected', async () => {
  resetBreakers();
  const saved = process.env.TURNSTILE_SECRET;
  delete process.env.TURNSTILE_SECRET;
  try {
    assert.equal(turnstileEnabled(), false);
    assert.deepEqual(await verifyTurnstile('any', { fetchImpl: okFetch() }), { ok: true, skipped: true });
    assert.deepEqual(await verifyTurnstile('', { fetchImpl: okFetch() }), { ok: true, skipped: true });
  } finally {
    if (saved === undefined) delete process.env.TURNSTILE_SECRET;
    else process.env.TURNSTILE_SECRET = saved;
  }
  assert.deepEqual(await verifyTurnstile('', withSecret), { ok: false, code: 'missing-input-response' });
});

test('valid token accepted, invalid rejected with code', async () => {
  resetBreakers();
  assert.deepEqual(await verifyTurnstile('tok', { ...withSecret, fetchImpl: okFetch(true) }), { ok: true });
  const bad = await verifyTurnstile('tok', { ...withSecret, fetchImpl: okFetch(false, ['invalid-input-response']) });
  assert.equal(bad.ok, false);
  assert.equal(bad.code, 'invalid-input-response');
});

test('provider down fails open with a metric', async () => {
  resetBreakers();
  resetMetrics();
  const seen = [];
  const r = await verifyTurnstile('tok', {
    ...withSecret,
    fetchImpl: () => Promise.reject(Object.assign(new Error('down'), { code: 'ECONNREFUSED' })),
    logger: (e) => seen.push(e),
  });
  assert.equal(r.ok, true);
  assert.equal(r.failOpen, true);
  assert.equal(seen[0].event, 'turnstile_failopen');
  assert.match(metricsText(), /integration_fallback_total\{provider="turnstile",reason="fail_open"\} 1/);
  const http500 = await verifyTurnstile('tok', {
    ...withSecret,
    fetchImpl: () => Promise.resolve({ ok: false, status: 500, json: () => Promise.resolve({}) }),
  });
  assert.equal(http500.ok, true);
  assert.equal(http500.failOpen, true);
});

const NS = testNamespace('bot');
after(() => {
  cleanupNamespace(NS);
});
// Low-entropy signup password for the HTTP proofs: the stub only hits the
// 'password' suffix, so anything else misses (high-entropy fixtures trip the
// secret scanner; see .gitleaks.toml).
const HTTP_PASS = 'SignupPass123';

test('HTTP: captcha enforced on signup only when secret set', async () => {
  const stub = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => {
      body += c;
    });
    req.on('end', () => {
      const ok = body.includes('response=good-token');
      res.setHeader('content-type', 'application/json');
      res.end(JSON.stringify(ok ? { success: true } : { success: false, 'error-codes': ['invalid-input-response'] }));
    });
  });
  await new Promise((resolve) => stub.listen(0, '127.0.0.1', resolve));
  const { port } = stub.address();
  const savedSecret = process.env.TURNSTILE_SECRET;
  const savedUrl = process.env.TURNSTILE_VERIFY_URL;
  process.env.TURNSTILE_SECRET = 'test-secret';
  process.env.TURNSTILE_VERIFY_URL = `http://127.0.0.1:${port}/siteverify`;
  try {
    const app = buildApp();
    const missing = await request(app)
      .post('/auth/signup')
      .send({
        email: uniqueEmail(NS, 'a'),
        password: HTTP_PASS,
        name: 'A',
        dob: '1990-01-01',
      });
    assert.equal(missing.status, 400);
    assert.equal(missing.body.error, 'CAPTCHA_REQUIRED');
    const bad = await request(app)
      .post('/auth/signup')
      .send({
        email: uniqueEmail(NS, 'b'),
        password: HTTP_PASS,
        name: 'B',
        dob: '1990-01-01',
        captchaToken: 'bad-token',
      });
    assert.equal(bad.status, 400);
    assert.equal(bad.body.error, 'CAPTCHA_REJECTED');
    const good = await request(app)
      .post('/auth/signup')
      .send({
        email: uniqueEmail(NS, 'c'),
        password: HTTP_PASS,
        name: 'C',
        dob: '1990-01-01',
        captchaToken: 'good-token',
      });
    assert.equal(good.status, 200);
  } finally {
    if (savedSecret === undefined) delete process.env.TURNSTILE_SECRET;
    else process.env.TURNSTILE_SECRET = savedSecret;
    if (savedUrl === undefined) delete process.env.TURNSTILE_VERIFY_URL;
    else process.env.TURNSTILE_VERIFY_URL = savedUrl;
    await new Promise((resolve) => stub.close(resolve));
  }
});
