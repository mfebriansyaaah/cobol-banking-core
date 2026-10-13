import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { buildApp } from '../src/app.js';
import { getVerificationCode } from './support.js';

const app = buildApp();

async function loginNewUser() {
  const email = `gw_sess_${Date.now()}_${Math.floor(Math.random() * 1e6)}@test.com`;
  await request(app)
    .post('/auth/signup')
    .send({ email, password: 'secret123', name: 'Session User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email, code: getVerificationCode(email) });
  const login = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  assert.equal(login.status, 200);
  return login.body.refreshToken;
}

test('refresh rotates the token: the old one stops working', async () => {
  const r1 = await loginNewUser();
  const first = await request(app).post('/auth/refresh').send({ refreshToken: r1 });
  assert.equal(first.status, 200);
  assert.ok(first.body.refreshToken);

  const reuse = await request(app).post('/auth/refresh').send({ refreshToken: r1 });
  assert.equal(reuse.status, 401);
  assert.equal(reuse.body.error, 'INVALID_REFRESH_TOKEN');
});

test('logout revokes the refresh token', async () => {
  const r1 = await loginNewUser();
  const out = await request(app).post('/auth/logout').send({ refreshToken: r1 });
  assert.equal(out.status, 200);
  assert.deepEqual(out.body.data, ['LOGGED_OUT']);

  const after = await request(app).post('/auth/refresh').send({ refreshToken: r1 });
  assert.equal(after.status, 401);
});

test('logout revokes the access token too', async () => {
  const email = `gw_rev_${Date.now()}_${Math.floor(Math.random() * 1e6)}@test.com`;
  await request(app).post('/auth/signup').send({ email, password: 'secret123', name: 'Revoke User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email, code: getVerificationCode(email) });
  const login = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  const auth = { Authorization: `Bearer ${login.body.token}` };

  assert.equal((await request(app).get(`/users/${email}`).set(auth)).status, 200);

  const out = await request(app).post('/auth/logout').send({ refreshToken: login.body.refreshToken });
  assert.equal(out.status, 200);

  // The same access token is now rejected before it would have expired.
  const after = await request(app).get(`/users/${email}`).set(auth);
  assert.equal(after.status, 401);
  assert.equal(after.body.error, 'TOKEN_REVOKED');
});
