import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { buildApp } from '../src/app.js';
import { assertSecureConfig } from '../src/auth.js';

test('security headers are set on responses', async () => {
  const app = buildApp();
  const res = await request(app).get('/nope');
  assert.equal(res.status, 404);
  assert.equal(res.headers['x-content-type-options'], 'nosniff');
  assert.ok(res.headers['x-frame-options']);
  assert.ok(res.headers['content-security-policy']);
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

    process.env.JWT_SECRET = 'a-strong-production-secret';
    process.env.REFRESH_SECRET = 'another-strong-production-secret';
    assert.doesNotThrow(() => assertSecureConfig());
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
