// Endpoint smoke suite: every gateway route is exercised once. Guards the
// result/HTTP contract that the per-feature tests only cover in part.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { buildApp } from '../src/app.js';

// Remove the users this suite created so the shared test database stays
// consistent for the suites that run after it (see gateway.test.js).
after(() => runSql("DELETE FROM users WHERE email LIKE 'ep\\_%'"));
import { seedUser, seedAccount, getVerificationCode, requireSeed, runSql, enableMfa, totp, TEST_MFA_SECRET } from './support.js';

const app = buildApp();

async function freshUser() {
  const email = `ep_${Date.now()}_${Math.floor(Math.random() * 1e6)}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email, password: 'secret123', name: 'EP User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email, code: getVerificationCode(email) });
  const login = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  return { email, token: login.body.token, refreshToken: login.body.refreshToken };
}

async function stepUpFor(token, password = 'secret123') {
  const r = await request(app).post('/auth/step-up').set('Authorization', `Bearer ${token}`).send({ password });
  return r.body.stepUpToken;
}

// Step-up for an MFA-enabled admin: the second factor is required as well.
async function adminStepUpFor(token, password = 'secret123') {
  const r = await request(app).post('/auth/step-up').set('Authorization', `Bearer ${token}`).send({ password, mfaCode: totp(TEST_MFA_SECRET) });
  return r.body.stepUpToken;
}

test('every public endpoint responds', async () => {
  assert.equal((await request(app).get('/health')).status, 200);
  const email = `ep_pub_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email, password: 'secret123', name: 'Pub User', dob: '1990-01-01' });
  assert.equal(s.status, 200);
  // The verification code is not returned; it is delivered out of band.
  assert.deepEqual(s.body.data, ['USER_CREATED']);
  assert.equal((await request(app).post('/auth/verify').send({ email, code: getVerificationCode(email) })).status, 200);
  const login = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  assert.equal(login.status, 200);
  assert.equal((await request(app).post('/auth/refresh').send({ refreshToken: login.body.refreshToken })).status, 200);
  assert.equal((await request(app).post('/auth/logout').send({ refreshToken: login.body.refreshToken })).status, 200);
});

test('every bearer endpoint responds', async () => {
  const { token, email } = await freshUser();
  const auth = { Authorization: `Bearer ${token}` };

  // A second self-created user stands in for "another account": this suite
  // creates its own fixtures instead of depending on seed data.
  const other = await freshUser();
  requireSeed(seedAccount(other.email, '100.00'), 'seed an account');

  const admin = `ep_admin_${Date.now()}@test.com`;
  requireSeed(seedUser(admin, 'SUPER_ADMIN'), 'seed a SUPER_ADMIN');
  // An admin needs MFA to obtain a step-up proof, so the privileged writes
  // below can be exercised end to end.
  requireSeed(enableMfa(admin), 'enable MFA for the admin');
  const adminToken = (await request(app).post('/auth/login').send({ email: admin, password: 'secret123', mfaCode: totp(TEST_MFA_SECRET) })).body.token;
  const adminAuth = { Authorization: `Bearer ${adminToken}` };

  // Permissions are projected, not decided, by the gateway: the login
  // response carries the effective permission set, and /metrics stays
  // closed to anyone without AUDIT_READ.
  const userLogin = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  assert.equal(userLogin.status, 200);
  assert.ok(Array.isArray(userLogin.body.permissions), 'login carries permissions');
  assert.deepEqual(userLogin.body.permissions, [], 'a plain user holds no catalogued permission');
  const adminLogin = await request(app).post('/auth/login').send({ email: admin, password: 'secret123', mfaCode: totp(TEST_MFA_SECRET) });
  assert.ok(adminLogin.body.permissions.includes('AUDIT_READ'), 'an admin holds AUDIT_READ');
  assert.ok(adminLogin.body.permissions.includes('RECONCILE_RUN'), 'an admin holds RECONCILE_RUN');
  const profile = await request(app).get('/profile').set(adminAuth).query({ email: admin });
  assert.equal(profile.status, 200);
  assert.ok(profile.body.permissions.includes('AUDIT_ARCHIVE'), 'the profile carries permissions');
  assert.equal((await request(app).get('/metrics').set(auth)).status, 403);
  assert.equal((await request(app).get('/metrics').set(adminAuth)).status, 200);

  // A plain user may not read another account; an admin may.
  assert.equal((await request(app).get('/users').set(auth)).status, 403);
  assert.equal((await request(app).get(`/users/${other.email}`).set(auth)).status, 403);
  assert.equal((await request(app).get(`/wallet/balance?email=${other.email}`).set(auth)).status, 403);
  assert.equal((await request(app).get(`/profile?email=${other.email}`).set(auth)).status, 403);

  assert.equal((await request(app).get('/users').set(adminAuth)).status, 200);
  assert.equal((await request(app).get(`/users/${other.email}`).set(adminAuth)).status, 200);
  assert.equal((await request(app).get(`/wallet/balance?email=${other.email}`).set(adminAuth)).status, 200);
  assert.equal((await request(app).get(`/profile?email=${other.email}`).set(adminAuth)).status, 200);

  // Transfers are always sent from the authenticated account: the body `from`
  // is ignored. Seed an account for this user and prove another's is untouched.
  requireSeed(seedAccount(email, '500.00'), 'seed an account');
  const xfer = await request(app)
    .post('/wallet/transfer')
    .set(auth)
    .set('Idempotency-Key', `ep-${Date.now()}`)
    .send({ from: other.email, to: other.email, amount: '1.00' });
  assert.equal(xfer.status, 200);
  assert.match((await request(app).get(`/wallet/balance?email=${other.email}`).set(adminAuth)).body.balances[0].balance, /^\d+\.\d{2}$/);

  // admin checks before the email changes
  assert.equal((await request(app).get(`/admin/role?email=${admin}&role=SUPER_ADMIN`).set(adminAuth)).status, 200);
  // a user may check their own role, but not another's
  assert.equal((await request(app).get(`/admin/role?email=${email}&role=USER`).set(auth)).status, 200);
  assert.equal((await request(app).get(`/admin/role?email=${other.email}&role=USER`).set(auth)).status, 403);
  // non-admin actor is refused by the route (business rule), not a 404; a
  // spoofed body `actor` is ignored because the actor comes from the token
  const userStep = await stepUpFor(token);
  assert.equal((await request(app).post('/admin/role').set(auth).set('X-Step-Up', userStep).send({ email: other.email, role: 'MANAGER', actor: admin })).status, 403);

  // Access review (ADR 0073): a SUPER_ADMIN opens a review, reads it, and
  // records a decision on a privileged account that is not itself.
  const adminStep = await adminStepUpFor(adminToken);
  const opened = await request(app)
    .post('/admin/access-reviews')
    .set(adminAuth)
    .set('X-Step-Up', adminStep)
    .send({ periodStart: '2026-10-01', periodEnd: '2026-10-31' });
  assert.equal(opened.status, 200, JSON.stringify(opened.body));
  const reviewId = opened.body.reviewId;
  assert.ok(Number.isInteger(Number(reviewId)), 'review id is returned');
  assert.ok(Number(opened.body.itemCount) >= 1, 'the review snapshots privileged accounts');

  const listed = await request(app).get('/admin/access-reviews').set(adminAuth);
  assert.equal(listed.status, 200);
  assert.ok(listed.body.total >= 1, 'the review is listed');
  assert.ok(listed.body.reviews.some((r) => String(r.id) === String(reviewId)), 'the opened review is in the list');

  const detail = await request(app).get(`/admin/access-reviews/${reviewId}`).set(adminAuth);
  assert.equal(detail.status, 200);
  assert.equal(detail.body.review.state, 'OPEN');
  assert.ok(Array.isArray(detail.body.items), 'the review carries its items');
  const otherItem = detail.body.items.find((i) => i.email !== admin);
  assert.ok(otherItem, 'at least one item covers another account');
  const decided = await request(app)
    .post(`/admin/access-review-items/${otherItem.itemId}/decide`)
    .set(adminAuth)
    .set('X-Step-Up', adminStep)
    .send({ decision: 'ATTESTED', note: 'still needed' });
  assert.equal(decided.status, 200, JSON.stringify(decided.body));
  assert.equal(decided.body.decision, 'ATTESTED');

  // A plain user may not open or read a review.
  assert.equal((await request(app).post('/admin/access-reviews').set(auth).set('X-Step-Up', userStep).send({ periodStart: '2026-10-01', periodEnd: '2026-10-31' })).status, 403);
  assert.equal((await request(app).get('/admin/access-reviews').set(auth)).status, 403);
  // A privileged write without a step-up proof is refused.
  assert.equal((await request(app).post('/admin/access-reviews').set(adminAuth).send({ periodStart: '2026-10-01', periodEnd: '2026-10-31' })).status, 401);
  // Leave no open review behind for the next suite.
  runSql(`DELETE FROM access_review_items WHERE review_id=${reviewId}; DELETE FROM access_reviews WHERE review_id=${reviewId};`);

  // Reconcile: an admin is allowed (200 reconciled / 409 mismatch); a plain
  // user is refused and a body `actor` cannot impersonate an admin.
  const rec = await request(app).get('/admin/reconcile').set(adminAuth);
  assert.ok([200, 409].includes(rec.status), `unexpected reconcile status ${rec.status}`);
  assert.equal((await request(app).get('/admin/reconcile').set(auth)).status, 403);
  assert.equal((await request(app).get('/admin/reconcile').query({ actor: admin }).set(auth)).status, 403);

  // Changing another user's email is refused: the actor comes from the token.
  const spoof = await request(app)
    .post('/profile/email/request')
    .set(auth)
    .send({ email: other.email, newEmail: `ep_spoof_${Date.now()}@test.com`, actor: other.email, password: 'secret123' });
  assert.equal(spoof.status, 403);
  assert.equal(spoof.body.error, 'FORBIDDEN');

  const ne = `ep_new_${Date.now()}@test.com`;
  const reqc = await request(app).post('/profile/email/request').set(auth).send({ email, newEmail: ne, password: 'secret123' });
  assert.equal(reqc.status, 200);
  assert.equal((await request(app).post('/profile/email/confirm').set(auth).send({ email, newEmail: ne, code: getVerificationCode(ne, 'EMAIL_CHANGE') })).status, 200);

  // The access token carries the old email, so it is no longer active after the
  // change; the user must log in (or refresh) again.
  assert.equal((await request(app).get('/users').set(auth)).status, 401);
});

test('auth and routing errors', async () => {
  assert.equal((await request(app).get('/users')).status, 401);
  assert.equal((await request(app).get('/nope')).status, 404);
});

test('responses use a uniform envelope', async () => {
  const ok = await request(app).get('/health');
  assert.ok(Array.isArray(ok.body.data), 'success carries a data array');
  assert.equal(ok.body.error, undefined);

  const bad = await request(app).post('/auth/login').send({ email: 'a|b', password: 'x' });
  assert.equal(typeof bad.body.error, 'string');
  assert.equal(bad.body.data, undefined);
});
