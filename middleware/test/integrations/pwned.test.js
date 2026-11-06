import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import http from 'node:http';
import request from 'supertest';
import { buildApp } from '../../src/app.js';
import { testNamespace, uniqueEmail, cleanupNamespace } from '../support.js';
import { assertPasswordAllowed, checkPassword, enforced, sha1Upper } from '../../src/integrations/security/pwned.js';
import { resetBreakers } from '../../src/integrations/resilience.js';
import { resetMetrics, metricsText } from '../../src/observability.js';

// 'password' is in every breach corpus; this string is not.
const UNIQUE = 'xQ9UniqueNeverBreached4f8c2aa71e';
const suffixOf = (pw) => createHash('sha1').update(pw).digest('hex').toUpperCase().slice(5);
const rangeFor = (suffix, count) => () =>
  Promise.resolve({ ok: true, status: 200, text: () => Promise.resolve(`${suffix}:${count}\nABCDEF123456:2\n`) });

test('k-anonymity: only the 5-char prefix travels', async () => {
  resetBreakers();
  let url = '';
  const r = await checkPassword('password', {
    fetchImpl: (u) => {
      url = u;
      return rangeFor(suffixOf('password'), 100)();
    },
  });
  assert.equal(r.breached, true);
  assert.equal(r.count, 100);
  assert.match(url, /\/range\/[0-9A-F]{5}$/);
  assert.ok(!/[0-9A-F]{40}/.test(url), 'full hash never travels');
});

test('breached passwords rejected, unique ones pass', async () => {
  resetBreakers();
  const hit = await checkPassword('password', { fetchImpl: rangeFor(suffixOf('password'), 3730503) });
  assert.equal(hit.breached, true);
  assert.equal(hit.count, 3730503);
  const miss = await checkPassword(UNIQUE, { fetchImpl: rangeFor('FFFFFFFFFF', 1) });
  assert.equal(miss.breached, false);
  assert.equal(miss.count, 0);
  assert.equal(
    await assertPasswordAllowed('password', {
      endpoint: 'https://x.test',
      fetchImpl: rangeFor(suffixOf('password'), 5),
    }),
    false,
  );
  assert.equal(
    await assertPasswordAllowed(UNIQUE, { endpoint: 'https://x.test', fetchImpl: rangeFor('FFFFFFFFFF', 1) }),
    true,
  );
});

test('threshold and empty input', async () => {
  resetBreakers();
  const under = await checkPassword('password', { fetchImpl: rangeFor(suffixOf('password'), 3), threshold: 10 });
  assert.equal(under.breached, false);
  assert.equal(under.count, 3);
  assert.deepEqual(await checkPassword('', { fetchImpl: () => Promise.reject(new Error('unused')) }), {
    breached: false,
    count: 0,
  });
});

test('API down fails open with a metric, never blocks', async () => {
  resetBreakers();
  resetMetrics();
  const seen = [];
  const ok = await assertPasswordAllowed('password', {
    endpoint: 'https://x.test',
    fetchImpl: () => Promise.reject(Object.assign(new Error('down'), { code: 'ECONNREFUSED' })),
    logger: (e) => seen.push(e),
  });
  assert.equal(ok, true);
  assert.equal(seen.length, 1);
  assert.equal(seen[0].event, 'pwned_failopen');
  assert.match(metricsText(), /integration_fallback_total\{provider="pwned",reason="fail_open"\} 1/);
});

test('sha1Upper is uppercase hex', () => {
  assert.match(sha1Upper('password'), /^[0-9A-F]{40}$/);
  assert.equal(sha1Upper('password'), '5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8');
});

test('enforcement matrix: opt-in except production default', () => {
  const save = {
    enforce: process.env.PWNED_ENFORCE,
    disable: process.env.PWNED_DISABLE,
    nodeEnv: process.env.NODE_ENV,
  };
  try {
    delete process.env.PWNED_ENFORCE;
    delete process.env.PWNED_DISABLE;
    delete process.env.NODE_ENV;
    assert.equal(enforced(), false);
    process.env.PWNED_ENFORCE = '1';
    assert.equal(enforced(), true);
    delete process.env.PWNED_ENFORCE;
    process.env.NODE_ENV = 'production';
    assert.equal(enforced(), true);
    process.env.PWNED_DISABLE = '1';
    assert.equal(enforced(), false);
  } finally {
    for (const [k, v] of [
      ['PWNED_ENFORCE', save.enforce],
      ['PWNED_DISABLE', save.disable],
      ['NODE_ENV', save.nodeEnv],
    ]) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  }
});

const NS = testNamespace('pwned');
after(() => {
  cleanupNamespace(NS);
});

test('HTTP: breached password rejected at signup, down API fails open', async () => {
  const suffix = suffixOf('password');
  const stub = http.createServer((req, res) => {
    res.setHeader('content-type', 'text/plain');
    res.end(`${suffix}:999\nABCDEF123456:2\n`);
  });
  await new Promise((resolve) => stub.listen(0, '127.0.0.1', resolve));
  const { port } = stub.address();
  const saved = process.env.PWNED_ENDPOINT;
  process.env.PWNED_ENDPOINT = `http://127.0.0.1:${port}`;
  try {
    const app = buildApp();
    const bad = await request(app)
      .post('/auth/signup')
      .send({ email: uniqueEmail(NS, 'bad'), password: 'password', name: 'Bad', dob: '1990-01-01' });
    assert.equal(bad.status, 400);
    assert.equal(bad.body.error, 'BREACHED_PASSWORD');
    const good = await request(app)
      .post('/auth/signup')
      .send({ email: uniqueEmail(NS, 'good'), password: UNIQUE, name: 'Good', dob: '1990-01-01' });
    assert.equal(good.status, 200);
  } finally {
    if (saved === undefined) delete process.env.PWNED_ENDPOINT;
    else process.env.PWNED_ENDPOINT = saved;
    await new Promise((resolve) => stub.close(resolve));
  }
  // Stub dead: a strong password still signs up (fail-open), proving
  // availability. ('password' would 400 on COBOL policy here, so use UNIQUE.)
  process.env.PWNED_ENDPOINT = `http://127.0.0.1:${port}`;
  try {
    const app = buildApp();
    const res = await request(app)
      .post('/auth/signup')
      .send({ email: uniqueEmail(NS, 'open'), password: UNIQUE, name: 'Open', dob: '1990-01-01' });
    assert.equal(res.status, 200);
  } finally {
    if (saved === undefined) delete process.env.PWNED_ENDPOINT;
    else process.env.PWNED_ENDPOINT = saved;
  }
});
