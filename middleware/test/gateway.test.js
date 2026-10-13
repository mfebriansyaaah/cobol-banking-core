import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { buildApp } from '../src/app.js';
import { seedUser, seedAccount, seedManyUsers, getVerificationCode } from './support.js';

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

test('signup -> verify -> login -> authorized call', async (t) => {
  const signup = await request(app)
    .post('/auth/signup')
    .send({ email: unique, password: 'secret123', name: 'Gateway User', dob: '1990-01-01' });
  assert.equal(signup.status, 200);
  // The code is delivered out of band, not returned.
  assert.deepEqual(signup.body.data, ['USER_CREATED']);
  const code = getVerificationCode(unique);
  assert.match(code, /^\d{6}$/);

  const verify = await request(app).post('/auth/verify').send({ email: unique, code });
  assert.equal(verify.status, 200);

  const login = await request(app)
    .post('/auth/login')
    .send({ email: unique, password: 'secret123' });
  assert.equal(login.status, 200);
  assert.ok(login.body.token);

  // Listing users is admin-only: a plain user is refused.
  const denied = await request(app).get('/users').set('Authorization', `Bearer ${login.body.token}`);
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error, 'FORBIDDEN');

  if (!seedUser('gw_admin_list@test.com', 'SUPER_ADMIN')) return t.skip('mysql unavailable to seed an admin');
  const adminToken = (await request(app).post('/auth/login').send({ email: 'gw_admin_list@test.com', password: 'secret123' })).body.token;

  const users = await request(app)
    .get('/users')
    .set('Authorization', `Bearer ${adminToken}`);
  assert.equal(users.status, 200);
  assert.ok(JSON.stringify(users.body.data).includes('LIST_DONE'));

  const paged = await request(app)
    .get('/users?limit=1&offset=0')
    .set('Authorization', `Bearer ${adminToken}`);
  assert.equal(paged.status, 200);
});

test('wrong password maps to 401', async () => {
  const res = await request(app)
    .post('/auth/login')
    .send({ email: unique, password: 'nope-nope' });
  assert.equal(res.status, 401);
  assert.equal(res.body.error, 'INVALID_CREDENTIALS');
});

test('bare-value endpoints return 200 with data', async (t) => {
  const em = `gw_bare_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Bare User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const login = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body;
  const auth = { Authorization: `Bearer ${login.token}` };

  // Reading another user's record/balance is forbidden for a plain user.
  assert.equal((await request(app).get('/users/sender@test.com').set(auth)).status, 403);
  assert.equal((await request(app).get('/wallet/balance?email=sender@test.com').set(auth)).status, 403);

  if (!seedUser('gw_admin_bare@test.com', 'SUPER_ADMIN')) return t.skip('mysql unavailable to seed an admin');
  const adminToken = (await request(app).post('/auth/login').send({ email: 'gw_admin_bare@test.com', password: 'secret123' })).body.token;
  const adminAuth = { Authorization: `Bearer ${adminToken}` };

  const user = await request(app).get('/users/sender@test.com').set(adminAuth);
  assert.equal(user.status, 200);
  assert.equal(user.body.data[0], '1');

  const bal = await request(app).get('/wallet/balance?email=sender@test.com').set(adminAuth);
  assert.equal(bal.status, 200);
  assert.match(bal.body.data[0], /^\d+\.\d{2}$/);
});

test('email change works for a logged-in user (related rows exist)', async () => {
  const em = `gw_conf_${Date.now()}@test.com`;
  const ne = `gw_confn_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Conf User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;

  const reqc = await request(app).post('/profile/email/request').set('Authorization', `Bearer ${token}`).send({ email: em, newEmail: ne });
  assert.equal(reqc.status, 200);
  const confirm = await request(app).post('/profile/email/confirm').set('Authorization', `Bearer ${token}`).send({ email: em, newEmail: ne, code: getVerificationCode(ne, 'EMAIL_CHANGE') });
  assert.equal(confirm.status, 200);
  assert.deepEqual(confirm.body.data, ['EMAIL_CHANGED']);
});

test('refresh token yields a new access token', async () => {
  const em = `gw_refresh_${Date.now()}@test.com`;
  const signup = await request(app)
    .post('/auth/signup')
    .send({ email: em, password: 'secret123', name: 'Refresh User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });

  const login = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });
  assert.ok(login.body.refreshToken);

  const refresh = await request(app).post('/auth/refresh').send({ refreshToken: login.body.refreshToken });
  assert.equal(refresh.status, 200);
  assert.ok(refresh.body.token);

  const users = await request(app).get(`/users/${em}`).set('Authorization', `Bearer ${refresh.body.token}`);
  assert.equal(users.status, 200);

  const bad = await request(app).post('/auth/refresh').send({ refreshToken: 'not-a-token' });
  assert.equal(bad.status, 401);
  assert.equal(bad.body.error, 'INVALID_REFRESH_TOKEN');
});

test('replaying a rotated refresh token revokes the whole family', async () => {
  const em = `gw_reuse_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Reuse User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const login = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });
  const r1 = login.body.refreshToken;

  const rotated = await request(app).post('/auth/refresh').send({ refreshToken: r1 });
  assert.equal(rotated.status, 200);
  const r2 = rotated.body.refreshToken;
  assert.ok(r2);

  // Replaying the old token is reuse -> 401, and the family is revoked.
  const replay = await request(app).post('/auth/refresh').send({ refreshToken: r1 });
  assert.equal(replay.status, 401);

  // The legitimate successor is now dead too; the user must log in again.
  const after = await request(app).post('/auth/refresh').send({ refreshToken: r2 });
  assert.equal(after.status, 401);
  assert.equal(after.body.error, 'INVALID_REFRESH_TOKEN');
});

test('role change authorizes by the token actor, ignoring the body', async (t) => {
  const admin = `gw_admin_${Date.now()}@test.com`;
  const target = `gw_target_${Date.now()}@test.com`;
  if (!seedUser(admin, 'SUPER_ADMIN') || !seedUser(target, 'USER')) {
    return t.skip('mysql client unavailable to seed a SUPER_ADMIN');
  }

  const adminLogin = await request(app).post('/auth/login').send({ email: admin, password: 'secret123' });
  assert.equal(adminLogin.status, 200);
  const adminToken = adminLogin.body.token;

  // The actor comes from the token: no `actor` in the body.
  const ok = await request(app)
    .post('/admin/role')
    .set('Authorization', `Bearer ${adminToken}`)
    .send({ email: target, role: 'MANAGER' });
  assert.equal(ok.status, 200);
  assert.deepEqual(ok.body.data, ['ROLE_CHANGED']);

  // A non-admin spoofing the admin in the body is still refused.
  const plainToken = (await request(app).post('/auth/login').send({ email: target, password: 'secret123' })).body.token;
  const spoof = await request(app)
    .post('/admin/role')
    .set('Authorization', `Bearer ${plainToken}`)
    .send({ email: target, role: 'USER', actor: admin });
  assert.equal(spoof.status, 403);
  assert.equal(spoof.body.error, 'FORBIDDEN');
});

test('reusing an idempotency key with different details is a conflict', async (t) => {
  const em = `gw_idem_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Idem User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  if (!seedAccount(em, '500.00')) return t.skip('mysql unavailable to seed an account');

  const key = `gw-${Date.now()}`;
  const first = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', key)
    .send({ to: 'receiver@test.com', amount: '1.00' });
  assert.equal(first.status, 200);

  const replay = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', key)
    .send({ to: 'receiver@test.com', amount: '1.00' });
  assert.equal(replay.status, 200);

  const conflict = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', key)
    .send({ to: 'receiver@test.com', amount: '2.00' });
  assert.equal(conflict.status, 409);
  assert.equal(conflict.body.error, 'IDEMPOTENCY_CONFLICT');
});

test('transfer amount is decided by COBOL, not the gateway shape', async (t) => {
  const em = `gw_amt_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Amt User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  if (!seedAccount(em, '100.00')) return t.skip('mysql unavailable to seed an account');

  // A numeric zero passes shape validation and is refused by COBOL.
  const zero = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', `zero-${Date.now()}`)
    .send({ to: 'receiver@test.com', amount: '0.00' });
  assert.equal(zero.status, 400);
  assert.equal(zero.body.error, 'INVALID_AMOUNT');

  // A non-numeric amount is a shape error, rejected before COBOL runs.
  const bad = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', `Bearer ${token}`)
    .send({ to: 'receiver@test.com', amount: 'abc' });
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, 'INVALID_PARAMETER');

  // Transferring to oneself is refused by COBOL.
  const self = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', `self-${Date.now()}`)
    .send({ to: em, amount: '1.00' });
  assert.equal(self.status, 400);
  assert.equal(self.body.error, 'SELF_TRANSFER');
});

test('the list page size is bounded', async (t) => {
  if (!seedUser('gw_admin_limit@test.com', 'SUPER_ADMIN')) return t.skip('mysql unavailable to seed an admin');
  const token = (await request(app).post('/auth/login').send({ email: 'gw_admin_limit@test.com', password: 'secret123' })).body.token;
  const auth = { Authorization: `Bearer ${token}` };

  assert.equal((await request(app).get('/users?limit=100').set(auth)).status, 200);
  assert.equal((await request(app).get('/users?limit=1&offset=0').set(auth)).status, 200);

  const tooBig = await request(app).get('/users?limit=101').set(auth);
  assert.equal(tooBig.status, 400);
  assert.equal(tooBig.body.error, 'INVALID_PARAMETER');

  assert.equal((await request(app).get('/users?limit=0').set(auth)).status, 400);
  assert.equal((await request(app).get('/users?limit=abc').set(auth)).status, 400);
});

test('a large list is not truncated at 500 bytes', async (t) => {
  if (!seedUser('gw_admin_bulk@test.com', 'SUPER_ADMIN')) return t.skip('mysql unavailable');
  if (!seedManyUsers('gw_bulk_', 25)) return t.skip('mysql unavailable');
  const token = (await request(app).post('/auth/login').send({ email: 'gw_admin_bulk@test.com', password: 'secret123' })).body.token;

  const res = await request(app).get('/users?limit=100').set('Authorization', `Bearer ${token}`);
  assert.equal(res.status, 200);
  // The 25th bulk user sits well past 500 bytes; it survives the multi-record output.
  assert.ok(JSON.stringify(res.body.data).includes('gw_bulk_25@test.com'));
});
