// Contract test per route (arch9 WP-13, T-13.4): every gateway route is
// exercised once through the real HTTP stack with a stubbed COBOL binary.
// Proves the I-04 wiring: a well-formed COBOL reply never becomes a 500,
// the response is valid JSON, and derived raw inputs (nik, imageRef,
// name/dob/consent, phone) are consumed server-side without leaking onto the
// 6-slot COBOL pipe. No database, no network: tokenStore is stubbed,
// derivations run against mock providers.
import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, chmod, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import request from 'supertest';

const dir = await mkdtemp(path.join(tmpdir(), 'cobol-route-contract-'));
const stub = path.join(dir, 'route-binary');
const capture = path.join(dir, 'capture.log');
await writeFile(
  stub,
  [
    '#!/bin/sh',
    'line=$(cat input.txt 2>/dev/null || true)',
    'action=$(printf "%s" "$line" | cut -d"|" -f1)',
    'printf "%s\\n" "$line" >> "$CAPTURE_FILE"',
    'case "$action" in',
    // GET_DISPUTE's mapper enforces an 11-field case row: a generic TEST_OK
    // is not well-formed output for it, so the stub answers in-shape.
    '  GET_DISPUTE) printf "%s" "SUCCESS|DISPUTE|1:contract@t.co:R1:Subject:Detail:OPEN:admin@t.co:2026-02-01:0:2026-01-01:none|1|m1:a@b.co:hello:2026-01-02" > output.txt ;;',
    '  *) printf "SUCCESS|TEST_OK" > output.txt ;;',
    'esac',
  ].join('\n') + '\n',
);
await chmod(stub, 0o755);
process.env.COBOL_BIN = stub;
process.env.CAPTURE_FILE = capture;
process.env.NIK_HMAC_SECRET = 'test-only-secret-0123456789abcdef';

const { buildApp } = await import('../src/app.js');
const { signToken, signStepUp } = await import('../src/auth.js');
const { ALL_ROUTES } = await import('../src/routes/index.js');

const tokenStore = {
  async isActive() {
    return true;
  },
  async revoke() {},
};

let app;
before(() => {
  app = buildApp({ tokenStore });
});

const EMAIL = 'contract@t.co';
const bearer = () => `Bearer ${signToken({ email: EMAIL, ver: 1, jti: 'route-contract-jti' })}`;
const stepUp = () => signStepUp({ email: EMAIL, ver: 1 });

// First candidate that satisfies the field regex wins. Ordered from most
// specific (email, date, phone, NIK) to most general so strict patterns match
// before loose ones swallow them.
const POOL = [
  'contract@t.co',
  '2026-01-01',
  '+6281234567890',
  '1234567890123456',
  '123456',
  '10.50',
  'USD',
  'OPEN',
  'John Doe-1',
  'CODE-001',
  'K-1',
  '7',
  '1',
  'secret123',
];

function sampleFor(pattern) {
  if (!pattern) return null;
  for (const c of POOL) {
    try {
      if (pattern.test(c)) return c;
    } catch {
      // A non-regex pattern: cannot sample, caller treats as missing.
    }
  }
  return null;
}

function valuesFor(route) {
  const values = {};
  for (const f of route.fields || []) {
    if (!f || !f.name || f.name === route.tokenIdentity) continue;
    if (!f.required) continue;
    const s = f.pattern ? sampleFor(f.pattern) : null;
    if (s !== null) values[f.name] = s;
  }
  // Derived raw inputs are client-sent (documented in OpenAPI) but never
  // enter the pipe: always include them so the sweep exercises derivations.
  for (const d of route.derivedFields || []) {
    if (!d || !d.name) continue;
    const s = d.pattern ? sampleFor(d.pattern) : null;
    if (s !== null) values[d.name] = s;
  }
  return values;
}

function pathFor(route, values) {
  return route.path.replace(/:([A-Za-z0-9_]+)/g, (_, n) => values[n] ?? '7');
}

async function callRoute(route, values) {
  const url = pathFor(route, values);
  const headers = { Authorization: bearer(), 'x-step-up': stepUp() };
  const agent = request(app);
  if (route.method === 'get') {
    return agent.get(url).set(headers).query(values);
  }
  return agent[route.method](url).set(headers).send(values);
}

async function pipeLines(action) {
  const text = await readFile(capture, 'utf8').catch(() => '');
  return text.split('\n').filter((ln) => ln.startsWith(`${action}|`));
}

test('IDV_NIK_VALIDATE derives server-side and keeps raw nik off the pipe', async () => {
  const rawNik = '1234567890123456';
  const res = await callRoute(
    { method: 'post', path: '/identity/nik/validate', fields: [], derivedFields: [] },
    { email: EMAIL, nik: rawNik },
  );
  assert.equal(res.status, 200);
  assert.equal(typeof res.body, 'object');
  const lines = await pipeLines('IDV_NIK_VALIDATE');
  assert.ok(lines.length >= 1, 'stub must have seen the authorize pipe line');
  for (const ln of lines) {
    assert.ok(!ln.includes(rawNik), `raw nik must not reach COBOL: ${ln}`);
    assert.match(ln, /[0-9a-f]{64}/, 'derived nikHash travels instead');
  }
});

test('IDV_KTP_OCR_RESULT keeps imageRef off the pipe', async () => {
  const res = await callRoute(
    { method: 'post', path: '/identity/ktp/ocr', fields: [], derivedFields: [] },
    { email: EMAIL, imageRef: 'IMG-9' },
  );
  assert.equal(res.status, 200);
  for (const ln of await pipeLines('IDV_KTP_OCR_RESULT')) {
    assert.ok(!ln.includes('IMG-9'), `raw imageRef must not reach COBOL: ${ln}`);
  }
});

test('SCR_SCREEN keeps the raw name off the pipe', async () => {
  const res = await callRoute(
    { method: 'post', path: '/screening/check', fields: [], derivedFields: [] },
    { email: EMAIL, name: 'John Doe', dob: '1990-01-01', consent: '1' },
  );
  assert.equal(res.status, 200);
  for (const ln of await pipeLines('SCR_SCREEN')) {
    assert.ok(!ln.includes('John Doe'), `raw name must not reach COBOL: ${ln}`);
    assert.match(ln, /[0-9a-f]{64}/, 'derived queryHash travels instead');
  }
});

test('OTP_LINK_BEGIN keeps the raw phone off the pipe', async () => {
  const res = await callRoute(
    { method: 'post', path: '/auth/phone/link/begin', fields: [], derivedFields: [] },
    { email: EMAIL, phone: '+6281234567890' },
  );
  assert.equal(res.status, 200);
  for (const ln of await pipeLines('OTP_LINK_BEGIN')) {
    assert.ok(!ln.includes('+6281234567890'), `raw phone must not reach COBOL: ${ln}`);
    assert.match(ln, /[0-9a-f]{64}/, 'derived phoneHash travels instead');
  }
});

test('missing derived input fails closed with 400, never 500', async () => {
  const res = await callRoute(
    { method: 'post', path: '/identity/nik/validate', fields: [], derivedFields: [] },
    { email: EMAIL },
  );
  assert.equal(res.status, 400);
  assert.equal(res.body.error, 'INVALID_PARAMETER');
});

test('every route answers without a 500 on well-formed COBOL output', async (t) => {
  // 559 = 554 pipe routes + 5 custom infra routes that carry an action
  // (health/PING, refresh, logout, revoke). Custom handlers run instead of
  // the pipe, but they share the auth/error contract under test here.
  const routes = ALL_ROUTES.filter((r) => r.action || r.custom);
  assert.ok(routes.length >= 559, `expected 559+ routes, got ${routes.length}`);
  for (const route of routes) {
    await t.test(`${route.method.toUpperCase()} ${route.path} → ${route.action}`, async () => {
      const res = await callRoute(route, valuesFor(route));
      assert.notEqual(res.status, 500, `${route.action}: ${JSON.stringify(res.body).slice(0, 200)}`);
      assert.equal(typeof res.body, 'object', `${route.action}: body must be JSON`);
    });
  }
});
