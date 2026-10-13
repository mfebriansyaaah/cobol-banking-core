// Endpoint smoke suite: every gateway route is exercised once. Guards the
// result/HTTP contract that the per-feature tests only cover in part.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { buildApp } from '../src/app.js';
import { seedUser, seedAccount } from './support.js';

const app = buildApp();

async function freshUser() {
  const email = `ep_${Date.now()}_${Math.floor(Math.random() * 1e6)}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email, password: 'secret123', name: 'EP User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email, code: s.body.data[1] });
  const login = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  return { email, token: login.body.token, refreshToken: login.body.refreshToken };
}

test('every public endpoint responds', async () => {
  assert.equal((await request(app).get('/health')).status, 200);
  const email = `ep_pub_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email, password: 'secret123', name: 'Pub User', dob: '1990-01-01' });
  assert.equal(s.status, 200);
  assert.equal((await request(app).post('/auth/verify').send({ email, code: s.body.data[1] })).status, 200);
  const login = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  assert.equal(login.status, 200);
  assert.equal((await request(app).post('/auth/refresh').send({ refreshToken: login.body.refreshToken })).status, 200);
  assert.equal((await request(app).post('/auth/logout').send({ refreshToken: login.body.refreshToken })).status, 200);
});

test('every bearer endpoint responds', async (t) => {
  const { token, email } = await freshUser();
  const auth = { Authorization: `Bearer ${token}` };

  const admin = `ep_admin_${Date.now()}@test.com`;
  if (!seedUser(admin, 'SUPER_ADMIN')) return t.skip('mysql unavailable to seed an admin');
  const adminToken = (await request(app).post('/auth/login').send({ email: admin, password: 'secret123' })).body.token;
  const adminAuth = { Authorization: `Bearer ${adminToken}` };

  // A plain user may not read another account; an admin may.
  assert.equal((await request(app).get('/users').set(auth)).status, 403);
  assert.equal((await request(app).get('/users/sender@test.com').set(auth)).status, 403);
  assert.equal((await request(app).get('/wallet/balance?email=sender@test.com').set(auth)).status, 403);
  assert.equal((await request(app).get('/profile?email=sender@test.com').set(auth)).status, 403);

  assert.equal((await request(app).get('/users').set(adminAuth)).status, 200);
  assert.equal((await request(app).get('/users/sender@test.com').set(adminAuth)).status, 200);
  assert.equal((await request(app).get('/wallet/balance?email=sender@test.com').set(adminAuth)).status, 200);
  assert.equal((await request(app).get('/profile?email=sender@test.com').set(adminAuth)).status, 200);

  // Transfers are always sent from the authenticated account: the body `from`
  // is ignored. Seed an account for this user and prove another's is untouched.
  if (!seedAccount(email, '500.00')) return t.skip('mysql unavailable to seed an account');
  const xfer = await request(app)
    .post('/wallet/transfer')
    .set(auth)
    .set('Idempotency-Key', `ep-${Date.now()}`)
    .send({ from: 'sender@test.com', to: 'receiver@test.com', amount: '1.00' });
  assert.equal(xfer.status, 200);
  assert.equal((await request(app).get('/wallet/balance?email=sender@test.com').set(adminAuth)).body.data[0], '1000.00');

  // admin checks before the email changes
  assert.equal((await request(app).get(`/admin/role?email=${admin}&role=SUPER_ADMIN`).set(adminAuth)).status, 200);
  // a user may check their own role, but not another's
  assert.equal((await request(app).get(`/admin/role?email=${email}&role=USER`).set(auth)).status, 200);
  assert.equal((await request(app).get('/admin/role?email=sender@test.com&role=USER').set(auth)).status, 403);
  // non-admin actor is refused by the route (business rule), not a 404; a
  // spoofed body `actor` is ignored because the actor comes from the token
  assert.equal((await request(app).post('/admin/role').set(auth).send({ email: 'receiver@test.com', role: 'MANAGER', actor: admin })).status, 403);

  // Reconcile: an admin is allowed (200 reconciled / 409 mismatch); a plain
  // user is refused and a body `actor` cannot impersonate an admin.
  const rec = await request(app).get('/admin/reconcile').set(adminAuth);
  assert.ok([200, 409].includes(rec.status), `unexpected reconcile status ${rec.status}`);
  assert.equal((await request(app).get('/admin/reconcile').set(auth)).status, 403);
  assert.equal((await request(app).get('/admin/reconcile').query({ actor: admin }).set(auth)).status, 403);

  const ne = `ep_new_${Date.now()}@test.com`;
  const reqc = await request(app).post('/profile/email/request').set(auth).send({ email, newEmail: ne });
  assert.equal(reqc.status, 200);
  assert.equal((await request(app).post('/profile/email/confirm').set(auth).send({ email, newEmail: ne, code: reqc.body.data[1] })).status, 200);

  // Changing another user's email is refused: the actor comes from the token.
  const spoof = await request(app)
    .post('/profile/email/request')
    .set(auth)
    .send({ email: 'sender@test.com', newEmail: `ep_spoof_${Date.now()}@test.com`, actor: 'sender@test.com' });
  assert.equal(spoof.status, 403);
  assert.equal(spoof.body.error, 'FORBIDDEN');
});

test('auth and routing errors', async () => {
  assert.equal((await request(app).get('/users')).status, 401);
  assert.equal((await request(app).get('/nope')).status, 404);
});
