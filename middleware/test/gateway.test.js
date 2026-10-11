import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { buildApp } from '../src/app.js';

const app = buildApp();
const unique = `gw_${Date.now()}@test.com`;

test('health is public and reports OK', async () => {
  const res = await request(app).get('/health');
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data, ['OK']);
});

test('injection characters are rejected before COBOL runs', async () => {
  const res = await request(app)
    .post('/auth/login')
    .send({ email: 'a|b; rm -rf /', password: 'x' });
  assert.equal(res.status, 400);
  assert.equal(res.body.error, 'INVALID_PARAMETER');
});

test('protected route requires a token', async () => {
  const res = await request(app).get('/users');
  assert.equal(res.status, 401);
  assert.equal(res.body.error, 'MISSING_TOKEN');
});

test('signup -> verify -> login -> authorized call', async () => {
  const signup = await request(app)
    .post('/auth/signup')
    .send({ email: unique, password: 'secret123', name: 'Gateway User', dob: '1990-01-01' });
  assert.equal(signup.status, 200);
  const [, code] = signup.body.data;
  assert.match(code, /^\d{6}$/);

  const verify = await request(app).post('/auth/verify').send({ email: unique, code });
  assert.equal(verify.status, 200);

  const login = await request(app)
    .post('/auth/login')
    .send({ email: unique, password: 'secret123' });
  assert.equal(login.status, 200);
  assert.ok(login.body.token);

  const users = await request(app)
    .get('/users')
    .set('Authorization', `Bearer ${login.body.token}`);
  assert.equal(users.status, 200);
  assert.ok(JSON.stringify(users.body.data).includes('LIST_DONE'));
});

test('wrong password maps to 401', async () => {
  const res = await request(app)
    .post('/auth/login')
    .send({ email: unique, password: 'nope-nope' });
  assert.equal(res.status, 401);
  assert.equal(res.body.error, 'INVALID_CREDENTIALS');
});
