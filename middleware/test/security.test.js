import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import jwt from 'jsonwebtoken';
import { buildApp, trustProxyWarning } from '../src/app.js';
import { assertSecureConfig } from '../src/auth.js';
import { getVerificationCode } from './support.js';

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

test('trustProxyWarning flags an unset or over-permissive TRUST_PROXY', () => {
  const saved = process.env.TRUST_PROXY;
  try {
    delete process.env.TRUST_PROXY;
    assert.match(trustProxyWarning(), /not set/);
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
  const saved = { NODE_ENV: process.env.NODE_ENV, JWT_SECRET: process.env.JWT_SECRET, REFRESH_SECRET: process.env.REFRESH_SECRET };
  const restore = () => {
    for (const key of Object.keys(saved)) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  };
  try {
    process.env.NODE_ENV = 'production';
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
