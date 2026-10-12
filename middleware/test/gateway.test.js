import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { buildApp } from '../src/app.js';

const app = buildApp();
const unique = `gw_${Date.now()}@test.com`;

test('health is public and reports deep status', async () => {
  const res = await request(app).get('/health');
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'ok');
  assert.equal(res.body.db, 'up');
  assert.ok(res.headers['x-cobol-ms'] !== undefined);
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

  const paged = await request(app)
    .get('/users?limit=1&offset=0')
    .set('Authorization', `Bearer ${login.body.token}`);
  assert.equal(paged.status, 200);
});

test('wrong password maps to 401', async () => {
  const res = await request(app)
    .post('/auth/login')
    .send({ email: unique, password: 'nope-nope' });
  assert.equal(res.status, 401);
  assert.equal(res.body.error, 'INVALID_CREDENTIALS');
});

test('bare-value endpoints return 200 with data', async () => {
  const em = `gw_bare_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Bare User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: s.body.data[1] });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;

  const user = await request(app).get('/users/sender@test.com').set('Authorization', `Bearer ${token}`);
  assert.equal(user.status, 200);
  assert.equal(user.body.data[0], '1');

  const bal = await request(app).get('/wallet/balance?email=sender@test.com').set('Authorization', `Bearer ${token}`);
  assert.equal(bal.status, 200);
  assert.match(bal.body.data[0], /^\d+\.\d{2}$/);
});

test('email change works for a logged-in user (related rows exist)', async () => {
  const em = `gw_conf_${Date.now()}@test.com`;
  const ne = `gw_confn_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Conf User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: s.body.data[1] });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;

  const reqc = await request(app).post('/profile/email/request').set('Authorization', `Bearer ${token}`).send({ email: em, newEmail: ne });
  assert.equal(reqc.status, 200);
  const confirm = await request(app).post('/profile/email/confirm').set('Authorization', `Bearer ${token}`).send({ email: em, newEmail: ne, code: reqc.body.data[1] });
  assert.equal(confirm.status, 200);
  assert.deepEqual(confirm.body.data, ['EMAIL_CHANGED']);
});

test('refresh token yields a new access token', async () => {
  const em = `gw_refresh_${Date.now()}@test.com`;
  const signup = await request(app)
    .post('/auth/signup')
    .send({ email: em, password: 'secret123', name: 'Refresh User', dob: '1990-01-01' });
  const [, code] = signup.body.data;
  await request(app).post('/auth/verify').send({ email: em, code });

  const login = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });
  assert.ok(login.body.refreshToken);

  const refresh = await request(app).post('/auth/refresh').send({ refreshToken: login.body.refreshToken });
  assert.equal(refresh.status, 200);
  assert.ok(refresh.body.token);

  const users = await request(app).get('/users').set('Authorization', `Bearer ${refresh.body.token}`);
  assert.equal(users.status, 200);

  const bad = await request(app).post('/auth/refresh').send({ refreshToken: 'not-a-token' });
  assert.equal(bad.status, 401);
  assert.equal(bad.body.error, 'INVALID_REFRESH_TOKEN');
});
