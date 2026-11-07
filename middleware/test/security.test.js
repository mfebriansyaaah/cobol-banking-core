import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import jwt from 'jsonwebtoken';
import { buildApp, trustProxyWarning } from '../src/app.js';
import { assertSecureConfig, verifyAccess, verifyRefresh, verifyStepUp } from '../src/auth.js';
import { buildParams, PATTERNS } from '../src/validation.js';
import { getVerificationCode, testNamespace, uniqueEmail, cleanupNamespace, queryScalar } from './support.js';

// Per-file fixture namespace with cleanup (see gateway.test.js).
const NS = testNamespace('sec');
const U = (tag) => uniqueEmail(NS, tag);
after(() => { cleanupNamespace(NS); });

test('security headers are set on responses', async () => {
  const app = buildApp();
  const res = await request(app).get('/nope');
  assert.equal(res.status, 404);
  assert.equal(res.headers['x-content-type-options'], 'nosniff');
  assert.ok(res.headers['x-frame-options']);
  assert.ok(res.headers['content-security-policy']);
});

test('oversized JSON bodies are rejected before COBOL runs', async () => {
  const app = buildApp();
  const big = await request(app)
    .post('/auth/signup')
    .send({ email: 'big@test.com', password: 'secret123', name: 'B'.repeat(25 * 1024), dob: '1990-01-01' });
  assert.equal(big.status, 413);
  assert.equal(big.body.error, 'BODY_TOO_LARGE');
  assert.equal(big.body.data, undefined);
  // Never reached the core: no verification code was stored for the sender.
  assert.equal(getVerificationCode('big@test.com'), '');
});

test('trustProxyWarning flags an over-permissive TRUST_PROXY', () => {
  const saved = process.env.TRUST_PROXY;
  try {
    // Unset is sound now (loopback-only default); only "true" warns.
    delete process.env.TRUST_PROXY;
    assert.equal(trustProxyWarning(), null);
    process.env.TRUST_PROXY = 'true';
    assert.match(trustProxyWarning(), /spoof/);
    process.env.TRUST_PROXY = '1';
    assert.equal(trustProxyWarning(), null);
  } finally {
    if (saved === undefined) delete process.env.TRUST_PROXY;
    else process.env.TRUST_PROXY = saved;
  }
});

test('assertSecureConfig refuses production with default secrets', () => {
  const saved = {
    NODE_ENV: process.env.NODE_ENV,
    JWT_SECRET: process.env.JWT_SECRET,
    REFRESH_SECRET: process.env.REFRESH_SECRET,
    DB_HOST: process.env.DB_HOST,
    DB_USER: process.env.DB_USER,
    DB_PASS: process.env.DB_PASS,
    DB_NAME: process.env.DB_NAME,
  };
  const restore = () => {
    for (const key of Object.keys(saved)) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  };
  try {
    process.env.NODE_ENV = 'production';
    // Explicit, non-default database settings so these cases isolate the
    // secret checks (the database guard has its own test below).
    process.env.DB_HOST = 'db.internal';
    process.env.DB_USER = 'app_rw';
    process.env.DB_PASS = 'a-strong-database-password-0003';
    process.env.DB_NAME = 'bank_prod';
    delete process.env.JWT_SECRET;
    delete process.env.REFRESH_SECRET;
    assert.throws(() => assertSecureConfig(), /refusing to start/);

    process.env.JWT_SECRET = 'a-strong-production-secret-value-0001';
    process.env.REFRESH_SECRET = 'another-strong-production-secret-0002';
    assert.doesNotThrow(() => assertSecureConfig());

    // Identical secrets are refused (access and refresh must not share a key).
    process.env.REFRESH_SECRET = process.env.JWT_SECRET;
    assert.throws(() => assertSecureConfig(), /must differ/);

    // Too-short secrets are refused.
    process.env.REFRESH_SECRET = 'short';
    assert.throws(() => assertSecureConfig(), /min 32 chars/);
  } finally {
    restore();
  }
});

test('assertSecureConfig refuses production with development database settings', () => {
  const saved = {
    NODE_ENV: process.env.NODE_ENV,
    JWT_SECRET: process.env.JWT_SECRET,
    REFRESH_SECRET: process.env.REFRESH_SECRET,
    DB_HOST: process.env.DB_HOST,
    DB_USER: process.env.DB_USER,
    DB_PASS: process.env.DB_PASS,
    DB_NAME: process.env.DB_NAME,
  };
  const restore = () => {
    for (const key of Object.keys(saved)) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  };
  try {
    process.env.NODE_ENV = 'production';
    process.env.JWT_SECRET = 'a-strong-production-secret-value-0001';
    process.env.REFRESH_SECRET = 'another-strong-production-secret-0002';
    process.env.DB_HOST = 'db.internal';
    process.env.DB_USER = 'app_rw';
    process.env.DB_PASS = 'a-strong-database-password-0003';
    process.env.DB_NAME = 'bank_prod';
    assert.doesNotThrow(() => assertSecureConfig());

    // The C bridge defaults are refused even when explicitly set.
    for (const [key, devDefault] of [['DB_USER', 'cobol_user'], ['DB_PASS', 'cobol_pass'], ['DB_NAME', 'cobol_db']]) {
      const good = process.env[key];
      process.env[key] = devDefault;
      assert.throws(() => assertSecureConfig(), /development default/, key);
      process.env[key] = good;
    }

    // Unset database settings are refused rather than silently defaulted.
    for (const key of ['DB_HOST', 'DB_USER', 'DB_PASS', 'DB_NAME']) {
      const good = process.env[key];
      delete process.env[key];
      assert.throws(() => assertSecureConfig(), /refusing to start/, key);
      process.env[key] = good;
    }
  } finally {
    restore();
  }
});

test('assertSecureConfig is permissive outside production', () => {
  const saved = { NODE_ENV: process.env.NODE_ENV, JWT_SECRET: process.env.JWT_SECRET };
  const restore = () => {
    for (const key of Object.keys(saved)) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  };
  try {
    process.env.NODE_ENV = 'test';
    delete process.env.JWT_SECRET;
    assert.doesNotThrow(() => assertSecureConfig());
  } finally {
    restore();
  }
});

test('tokens must carry the expected issuer and audience', async () => {
  const app = buildApp();
  const secret = process.env.JWT_SECRET || 'dev-secret-change-me';
  const payload = { email: 'iss@test.com', ver: 1, jti: 'j' };
  const noScope = jwt.sign(payload, secret, { expiresIn: '5m' });
  const wrongScope = jwt.sign(payload, secret, { expiresIn: '5m', issuer: 'cobol-banking-core', audience: 'someone-else' });
  for (const token of [noScope, wrongScope]) {
    const res = await request(app).get('/users').set('Authorization', `Bearer ${token}`);
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'INVALID_TOKEN');
  }
});

test('access tokens are pinned to HS256', async () => {
  const app = buildApp();
  const secret = process.env.JWT_SECRET || 'dev-secret-change-me';
  const payload = { email: 'alg@test.com', ver: 1, jti: 'j' };
  const claims = { issuer: 'cobol-banking-core', audience: 'cobol-banking-api' };
  const hs384 = jwt.sign(payload, secret, { expiresIn: '5m', algorithm: 'HS384', ...claims });
  const res = await request(app).get('/users').set('Authorization', `Bearer ${hs384}`);
  assert.equal(res.status, 401);
  assert.equal(res.body.error, 'INVALID_TOKEN');
});

const ROT_CLAIMS = { issuer: 'cobol-banking-core', audience: 'cobol-banking-api' };
const ROT_PREV = 'previous-rotation-secret-value-0001';
const ROT_UNKNOWN = 'never-configured-secret-value-0002';
const inSeconds = (deltaSeconds) => String(Math.floor(Date.now() / 1000) + deltaSeconds);

function withPrevious(env) {
  const saved = {};
  for (const key of Object.keys(env)) {
    saved[key] = process.env[key];
    if (env[key] === undefined) delete process.env[key];
    else process.env[key] = env[key];
  }
  return () => {
    for (const key of Object.keys(saved)) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  };
}

test('access tokens minted before rotation still verify', () => {
  const restore = withPrevious({ JWT_SECRET_PREVIOUS: ROT_PREV, JWT_SECRET_PREVIOUS_UNTIL: inSeconds(300) });
  try {
    const prevToken = jwt.sign({ email: 'rot@test.com' }, ROT_PREV, { expiresIn: '5m', ...ROT_CLAIMS });
    assert.equal(verifyAccess(prevToken).email, 'rot@test.com');
    const unknownToken = jwt.sign({ email: 'rot@test.com' }, ROT_UNKNOWN, { expiresIn: '5m', ...ROT_CLAIMS });
    assert.equal(verifyAccess(unknownToken), null);
  } finally {
    restore();
  }
});

test('refresh tokens minted before rotation still verify', () => {
  const restore = withPrevious({ REFRESH_SECRET_PREVIOUS: ROT_PREV, REFRESH_SECRET_PREVIOUS_UNTIL: inSeconds(300) });
  try {
    const prevToken = jwt.sign({ email: 'rot@test.com', jti: 'j' }, ROT_PREV, { expiresIn: '5m', ...ROT_CLAIMS });
    assert.equal(verifyRefresh(prevToken).email, 'rot@test.com');
    const unknownToken = jwt.sign({ email: 'rot@test.com', jti: 'j' }, ROT_UNKNOWN, { expiresIn: '5m', ...ROT_CLAIMS });
    assert.throws(() => verifyRefresh(unknownToken));
  } finally {
    restore();
  }
});

test('step-up tokens minted before rotation still verify, purpose still enforced', () => {
  const restore = withPrevious({ JWT_SECRET_PREVIOUS: ROT_PREV, JWT_SECRET_PREVIOUS_UNTIL: inSeconds(300) });
  try {
    const prevToken = jwt.sign({ email: 'rot@test.com', purpose: 'step-up' }, ROT_PREV, { expiresIn: '5m', ...ROT_CLAIMS });
    assert.equal(verifyStepUp(prevToken).email, 'rot@test.com');
    // A purpose-tagged token is not an access token, even across rotation.
    assert.equal(verifyAccess(prevToken), null);
    // An untagged token is not a step-up proof, even across rotation.
    const noPurpose = jwt.sign({ email: 'rot@test.com' }, ROT_PREV, { expiresIn: '5m', ...ROT_CLAIMS });
    assert.throws(() => verifyStepUp(noPurpose), /not a step-up token/);
    const unknownToken = jwt.sign({ email: 'rot@test.com', purpose: 'step-up' }, ROT_UNKNOWN, { expiresIn: '5m', ...ROT_CLAIMS });
    assert.throws(() => verifyStepUp(unknownToken));
  } finally {
    restore();
  }
});

test('rotated access tokens pass the bearer middleware', async () => {
  const app = buildApp();
  const restore = withPrevious({ JWT_SECRET_PREVIOUS: ROT_PREV, JWT_SECRET_PREVIOUS_UNTIL: inSeconds(300) });
  try {
    // Valid signature under the previous secret: requireAuth passes and the
    // request fails later at token activeness (unknown jti), not at auth.
    const prevToken = jwt.sign({ email: 'rot@test.com', ver: 1, jti: 'no-such-session' }, ROT_PREV, { expiresIn: '5m', ...ROT_CLAIMS });
    const past = await request(app).get('/users').set('Authorization', `Bearer ${prevToken}`);
    assert.equal(past.status, 401);
    assert.equal(past.body.error, 'TOKEN_REVOKED');
    // Unknown secret fails at auth itself.
    const unknownToken = jwt.sign({ email: 'rot@test.com', ver: 1, jti: 'no-such-session' }, ROT_UNKNOWN, { expiresIn: '5m', ...ROT_CLAIMS });
    const stopped = await request(app).get('/users').set('Authorization', `Bearer ${unknownToken}`);
    assert.equal(stopped.status, 401);
    assert.equal(stopped.body.error, 'INVALID_TOKEN');
  } finally {
    restore();
  }
});

test('assertSecureConfig guards previous secrets in production', () => {
  const saved = { NODE_ENV: process.env.NODE_ENV, JWT_SECRET: process.env.JWT_SECRET, REFRESH_SECRET: process.env.REFRESH_SECRET, JWT_SECRET_PREVIOUS: process.env.JWT_SECRET_PREVIOUS, JWT_SECRET_PREVIOUS_UNTIL: process.env.JWT_SECRET_PREVIOUS_UNTIL, REFRESH_SECRET_PREVIOUS: process.env.REFRESH_SECRET_PREVIOUS, REFRESH_SECRET_PREVIOUS_UNTIL: process.env.REFRESH_SECRET_PREVIOUS_UNTIL, DB_HOST: process.env.DB_HOST, DB_USER: process.env.DB_USER, DB_PASS: process.env.DB_PASS, DB_NAME: process.env.DB_NAME };
  const restore = () => {
    for (const key of Object.keys(saved)) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  };
  try {
    process.env.NODE_ENV = 'production';
    process.env.JWT_SECRET = 'a-strong-production-secret-value-0001';
    process.env.REFRESH_SECRET = 'another-strong-production-secret-0002';
    // Explicit, non-default database settings so this case isolates the
    // previous-secret checks.
    process.env.DB_HOST = 'db.internal';
    process.env.DB_USER = 'app_rw';
    process.env.DB_PASS = 'a-strong-database-password-0003';
    process.env.DB_NAME = 'bank_prod';
    delete process.env.JWT_SECRET_PREVIOUS;
    delete process.env.REFRESH_SECRET_PREVIOUS;
    delete process.env.JWT_SECRET_PREVIOUS_UNTIL;
    delete process.env.REFRESH_SECRET_PREVIOUS_UNTIL;
    assert.doesNotThrow(() => assertSecureConfig());

    // A staged previous secret always carries its overlap deadline here.
    process.env.JWT_SECRET_PREVIOUS_UNTIL = inSeconds(3600);
    process.env.REFRESH_SECRET_PREVIOUS_UNTIL = inSeconds(3600);

    // Default, short, or current-equal previous values are refused.
    process.env.JWT_SECRET_PREVIOUS = 'dev-secret-change-me';
    assert.throws(() => assertSecureConfig(), /JWT_SECRET_PREVIOUS/);
    process.env.JWT_SECRET_PREVIOUS = 'short';
    assert.throws(() => assertSecureConfig(), /min 32 chars/);
    process.env.JWT_SECRET_PREVIOUS = process.env.JWT_SECRET;
    assert.throws(() => assertSecureConfig(), /must differ/);
    process.env.JWT_SECRET_PREVIOUS = 'a-strong-previous-secret-value-0003';

    process.env.REFRESH_SECRET_PREVIOUS = 'dev-refresh-secret-change-me';
    assert.throws(() => assertSecureConfig(), /REFRESH_SECRET_PREVIOUS/);
    process.env.REFRESH_SECRET_PREVIOUS = 'short';
    assert.throws(() => assertSecureConfig(), /min 32 chars/);
    process.env.REFRESH_SECRET_PREVIOUS = process.env.REFRESH_SECRET;
    assert.throws(() => assertSecureConfig(), /must differ/);
    process.env.REFRESH_SECRET_PREVIOUS = 'another-strong-previous-secret-0004';
    assert.doesNotThrow(() => assertSecureConfig());
  } finally {
    restore();
  }
});

test('a previous secret is honored only until its overlap deadline', () => {
  const prevToken = jwt.sign({ email: 'rot@test.com' }, ROT_PREV, { expiresIn: '5m', ...ROT_CLAIMS });
  // Deadline in the future: the staged secret still verifies.
  let restore = withPrevious({ JWT_SECRET_PREVIOUS: ROT_PREV, JWT_SECRET_PREVIOUS_UNTIL: inSeconds(60) });
  try {
    assert.equal(verifyAccess(prevToken).email, 'rot@test.com');
  } finally {
    restore();
  }
  // Deadline passed: the same secret stops being accepted.
  restore = withPrevious({ JWT_SECRET_PREVIOUS: ROT_PREV, JWT_SECRET_PREVIOUS_UNTIL: inSeconds(-60) });
  try {
    assert.equal(verifyAccess(prevToken), null);
  } finally {
    restore();
  }
  // No deadline at all: not honored (the overlap must be bounded).
  restore = withPrevious({ JWT_SECRET_PREVIOUS: ROT_PREV, JWT_SECRET_PREVIOUS_UNTIL: undefined });
  try {
    assert.equal(verifyAccess(prevToken), null);
  } finally {
    restore();
  }
  // A malformed deadline is treated the same as a missing one.
  restore = withPrevious({ JWT_SECRET_PREVIOUS: ROT_PREV, JWT_SECRET_PREVIOUS_UNTIL: 'soon' });
  try {
    assert.equal(verifyAccess(prevToken), null);
  } finally {
    restore();
  }
});

test('production requires an overlap deadline for a staged previous secret', () => {
  const saved = { NODE_ENV: process.env.NODE_ENV, JWT_SECRET: process.env.JWT_SECRET, REFRESH_SECRET: process.env.REFRESH_SECRET, JWT_SECRET_PREVIOUS: process.env.JWT_SECRET_PREVIOUS, JWT_SECRET_PREVIOUS_UNTIL: process.env.JWT_SECRET_PREVIOUS_UNTIL, REFRESH_SECRET_PREVIOUS: process.env.REFRESH_SECRET_PREVIOUS, REFRESH_SECRET_PREVIOUS_UNTIL: process.env.REFRESH_SECRET_PREVIOUS_UNTIL, DB_HOST: process.env.DB_HOST, DB_USER: process.env.DB_USER, DB_PASS: process.env.DB_PASS, DB_NAME: process.env.DB_NAME };
  const restore = () => {
    for (const key of Object.keys(saved)) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  };
  try {
    process.env.NODE_ENV = 'production';
    process.env.JWT_SECRET = 'a-strong-production-secret-value-0001';
    process.env.REFRESH_SECRET = 'another-strong-production-secret-0002';
    process.env.DB_HOST = 'db.internal';
    process.env.DB_USER = 'app_rw';
    process.env.DB_PASS = 'a-strong-database-password-0003';
    process.env.DB_NAME = 'bank_prod';
    delete process.env.JWT_SECRET_PREVIOUS;
    delete process.env.REFRESH_SECRET_PREVIOUS;
    delete process.env.JWT_SECRET_PREVIOUS_UNTIL;
    delete process.env.REFRESH_SECRET_PREVIOUS_UNTIL;
    assert.doesNotThrow(() => assertSecureConfig());

    process.env.JWT_SECRET_PREVIOUS = 'a-strong-previous-secret-value-0005';
    assert.throws(() => assertSecureConfig(), /JWT_SECRET_PREVIOUS_UNTIL/);
    process.env.JWT_SECRET_PREVIOUS_UNTIL = 'not-a-number';
    assert.throws(() => assertSecureConfig(), /JWT_SECRET_PREVIOUS_UNTIL/);
    process.env.JWT_SECRET_PREVIOUS_UNTIL = '0';
    assert.throws(() => assertSecureConfig(), /JWT_SECRET_PREVIOUS_UNTIL/);
    process.env.JWT_SECRET_PREVIOUS_UNTIL = inSeconds(3600);
    assert.doesNotThrow(() => assertSecureConfig());

    // A deadline in the past is a completed rotation, not a misconfiguration:
    // the secret is simply no longer honored.
    process.env.JWT_SECRET_PREVIOUS_UNTIL = inSeconds(-3600);
    assert.doesNotThrow(() => assertSecureConfig());
  } finally {
    restore();
  }
});

test('secrets shared across the rotation family are refused', () => {
  const saved = { NODE_ENV: process.env.NODE_ENV, JWT_SECRET: process.env.JWT_SECRET, REFRESH_SECRET: process.env.REFRESH_SECRET, JWT_SECRET_PREVIOUS: process.env.JWT_SECRET_PREVIOUS, JWT_SECRET_PREVIOUS_UNTIL: process.env.JWT_SECRET_PREVIOUS_UNTIL, REFRESH_SECRET_PREVIOUS: process.env.REFRESH_SECRET_PREVIOUS, REFRESH_SECRET_PREVIOUS_UNTIL: process.env.REFRESH_SECRET_PREVIOUS_UNTIL, DB_HOST: process.env.DB_HOST, DB_USER: process.env.DB_USER, DB_PASS: process.env.DB_PASS, DB_NAME: process.env.DB_NAME };
  const restore = () => {
    for (const key of Object.keys(saved)) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  };
  try {
    process.env.NODE_ENV = 'production';
    process.env.JWT_SECRET = 'a-strong-production-secret-value-0001';
    process.env.REFRESH_SECRET = 'another-strong-production-secret-0002';
    process.env.DB_HOST = 'db.internal';
    process.env.DB_USER = 'app_rw';
    process.env.DB_PASS = 'a-strong-database-password-0003';
    process.env.DB_NAME = 'bank_prod';
    delete process.env.JWT_SECRET_PREVIOUS;
    delete process.env.REFRESH_SECRET_PREVIOUS;
    delete process.env.JWT_SECRET_PREVIOUS_UNTIL;
    delete process.env.REFRESH_SECRET_PREVIOUS_UNTIL;

    // A token signed for one purpose must not verify as another, so no two
    // configured secrets may share a value.
    process.env.JWT_SECRET_PREVIOUS = process.env.REFRESH_SECRET;
    process.env.JWT_SECRET_PREVIOUS_UNTIL = inSeconds(3600);
    assert.throws(() => assertSecureConfig(), /must differ/);
    process.env.JWT_SECRET_PREVIOUS = process.env.JWT_SECRET;
    assert.throws(() => assertSecureConfig(), /must differ/);
    process.env.JWT_SECRET_PREVIOUS = 'a-strong-previous-secret-value-0005';
    assert.doesNotThrow(() => assertSecureConfig());

    process.env.REFRESH_SECRET_PREVIOUS = process.env.JWT_SECRET;
    process.env.REFRESH_SECRET_PREVIOUS_UNTIL = inSeconds(3600);
    assert.throws(() => assertSecureConfig(), /must differ/);
    process.env.REFRESH_SECRET_PREVIOUS = process.env.JWT_SECRET_PREVIOUS;
    assert.throws(() => assertSecureConfig(), /must differ/);
    process.env.REFRESH_SECRET_PREVIOUS = 'another-strong-previous-secret-0006';
    assert.doesNotThrow(() => assertSecureConfig());
  } finally {
    restore();
  }
});

test('error records carry the route template, never the raw URL', async () => {
  const lines = [];
  const app = buildApp({ logger: (line) => lines.push(line) });
  // An unmatched path with PII-shaped content must not land in logs raw.
  await request(app).get('/users/someone@test.com');
  const err = lines.find((l) => l.event === 'gateway_error');
  assert.ok(!JSON.stringify(lines).includes('someone@test.com'));
  assert.ok(!err || err.url === undefined);
});

test('a none-algorithm token is rejected', async () => {
  const app = buildApp();
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const forged = `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ email: 'none@test.com' })}.`;
  const res = await request(app).get('/users').set('Authorization', `Bearer ${forged}`);
  assert.equal(res.status, 401);
  assert.equal(res.body.error, 'INVALID_TOKEN');
});

test('pipe and control characters in free-text fields are rejected', async () => {
  const app = buildApp();
  for (const [tag, name] of [['pipe', 'Pipe|Smuggle'], ['nl', 'New\nLine'], ['cr', 'Carriage\rReturn']]) {
    const res = await request(app)
      .post('/auth/signup')
      .send({ email: U(`free-${tag}`), password: 'secret123', name, dob: '1990-01-01' });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'INVALID_PARAMETER');
  }
});

test('mass assignment: undeclared body fields never reach the core', () => {
  const spec = { fields: [{ name: 'email', pattern: PATTERNS.EMAIL, required: true }] };
  assert.deepEqual(buildParams(spec, { email: 'a@test.com', role: 'SUPER_ADMIN', actor: 'root@test.com' }), [
    'a@test.com',
  ]);
});

test('mass assignment over HTTP: role/status extras do not escalate signup', async () => {
  const app = buildApp();
  const em = U('mass');
  const res = await request(app)
    .post('/auth/signup')
    .send({ email: em, password: 'secret123', name: 'Mass', dob: '1990-01-01', role: 'SUPER_ADMIN', status: 'VERIFIED' });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data, ['USER_CREATED']);
  assert.equal(queryScalar(`SELECT role FROM users WHERE email='${em}';`), 'USER');
  assert.equal(queryScalar(`SELECT status FROM users WHERE email='${em}';`), 'UNVERIFIED');
});

test('passwords never appear in emitted log lines', async () => {
  const lines = [];
  const app = buildApp({ logger: (line) => lines.push(JSON.stringify(line)) });
  const bad = await request(app)
    .post('/auth/signup')
    .send({ email: 'not-an-email', password: 'Sup3rSecret-PW', name: 'N', dob: '2000-01-01' });
  assert.equal(bad.status, 400);
  assert.ok(lines.length > 0, 'error path emits log lines');
  assert.ok(lines.every((l) => !l.includes('Sup3rSecret-PW')));
});
