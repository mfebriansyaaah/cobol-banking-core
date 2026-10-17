import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { execFile } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import request from 'supertest';
import { buildApp } from '../src/app.js';
import { seedUser, seedAccount, seedManyUsers, getVerificationCode, runSql, enableMfa, TEST_MFA_SECRET, requireSeed } from './support.js';

const app = buildApp();
const unique = `gw_${Date.now()}@test.com`;

// RFC 6238 TOTP (SHA-1 / 6 digits / 30s) for the MFA test below.
function fromBase32(s) {
  const alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = 0, value = 0;
  const out = [];
  for (const ch of s) {
    const idx = alpha.indexOf(ch);
    if (idx === -1) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

function totp(secret) {
  // Near the end of a 30s window, mint the NEXT step's code instead: the
  // server accepts ±1 step, so this removes the boundary race where a code
  // computed in step N is only verified in step N+2 under load.
  const now = Date.now();
  let step = Math.floor(now / 30000);
  if (now % 30000 > 25000) step += 1;
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64BE(BigInt(step));
  const h = createHmac('sha1', fromBase32(secret)).update(buf).digest();
  const o = h[h.length - 1] & 0xf;
  const bin = ((h[o] & 0x7f) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3];
  return String(bin % 1000000).padStart(6, '0');
}

// Obtain a step-up proof (header value) for a bearer token; required by the
// privileged admin writes.
async function stepUpFor(token, password = 'secret123') {
  const r = await request(app).post('/auth/step-up').set('Authorization', `Bearer ${token}`).send({ password, mfaCode: totp(TEST_MFA_SECRET) });
  return r.body.stepUpToken;
}

// Log in an MFA-enabled admin (seeded via enableMfa) and return the access token.
async function adminLoginFor(email, password = 'secret123') {
  const r = await request(app).post('/auth/login').send({ email, password, mfaCode: totp(TEST_MFA_SECRET) });
  return r.body.token;
}

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

  requireSeed(seedUser('gw_admin_list@test.com', 'SUPER_ADMIN'), 'seed a SUPER_ADMIN');
  const adminToken = (await request(app).post('/auth/login').send({ email: 'gw_admin_list@test.com', password: 'secret123' })).body.token;

  const users = await request(app)
    .get('/users')
    .set('Authorization', `Bearer ${adminToken}`);
  assert.equal(users.status, 200);
  assert.equal(users.body.data[0], 'USERS');
  assert.ok(Array.isArray(users.body.users));

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

test('bare-value endpoints return 200 with data', async () => {
  const em = `gw_bare_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Bare User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const login = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body;
  const auth = { Authorization: `Bearer ${login.token}` };

  // Reading another user's record/balance is forbidden for a plain user.
  assert.equal((await request(app).get('/users/sender@test.com').set(auth)).status, 403);
  assert.equal((await request(app).get('/wallet/balance?email=sender@test.com').set(auth)).status, 403);

  requireSeed(seedUser('gw_admin_bare@test.com', 'SUPER_ADMIN'), 'seed a SUPER_ADMIN');
  const adminToken = (await request(app).post('/auth/login').send({ email: 'gw_admin_bare@test.com', password: 'secret123' })).body.token;
  const adminAuth = { Authorization: `Bearer ${adminToken}` };

  const user = await request(app).get('/users/sender@test.com').set(adminAuth);
  assert.equal(user.status, 200);
  assert.equal(user.body.data[0], 'USER');
  assert.equal(user.body.user.id, '1');

  const bal = await request(app).get('/wallet/balance?email=sender@test.com').set(adminAuth);
  assert.equal(bal.status, 200);
  assert.equal(bal.body.data[0], 'BALANCES');
  assert.match(bal.body.balances[0].balance, /^\d+\.\d{2}$/);
});

test('email change works for a logged-in user (related rows exist)', async () => {
  const em = `gw_conf_${Date.now()}@test.com`;
  const ne = `gw_confn_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Conf User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;

  const reqc = await request(app).post('/profile/email/request').set('Authorization', `Bearer ${token}`).send({ email: em, newEmail: ne, password: 'secret123' });
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

test('role change authorizes by the token actor, ignoring the body', async () => {
  const admin = `gw_admin_${Date.now()}@test.com`;
  const target = `gw_target_${Date.now()}@test.com`;
  const plainUser = `gw_plain_${Date.now()}@test.com`;
  requireSeed(seedUser(admin, 'SUPER_ADMIN') && seedUser(target, 'USER') && seedUser(plainUser, 'USER'), 'seed role-change users');
  enableMfa(admin);

  const adminLogin = await request(app).post('/auth/login').send({ email: admin, password: 'secret123', mfaCode: totp(TEST_MFA_SECRET) });
  assert.equal(adminLogin.status, 200);
  const adminToken = adminLogin.body.token;
  const adminStep = await stepUpFor(adminToken);

  // The actor comes from the token: no `actor` in the body.
  const ok = await request(app)
    .post('/admin/role')
    .set('Authorization', `Bearer ${adminToken}`)
    .set('X-Step-Up', adminStep)
    .send({ email: target, role: 'MANAGER' });
  assert.equal(ok.status, 200);
  assert.deepEqual(ok.body.data, ['ROLE_CHANGED']);

  // A non-admin spoofing the admin in the body is still refused.
  const plainToken = (await request(app).post('/auth/login').send({ email: plainUser, password: 'secret123' })).body.token;
  const plainStep = await stepUpFor(plainToken);
  const spoof = await request(app)
    .post('/admin/role')
    .set('Authorization', `Bearer ${plainToken}`)
    .set('X-Step-Up', plainStep)
    .send({ email: target, role: 'USER', actor: admin });
  assert.equal(spoof.status, 403);
  assert.equal(spoof.body.error, 'FORBIDDEN');
});

test('admin audit trail is readable by a SUPER_ADMIN only', async () => {
  const admin = `gw_audit_${Date.now()}@test.com`;
  const target = `gw_audit_t_${Date.now()}@test.com`;
  requireSeed(seedUser(admin, 'SUPER_ADMIN') && seedUser(target, 'USER'), 'seed audit-trail users');
  enableMfa(admin);
  const adminToken = await adminLoginFor(admin);
  const userToken = (await request(app).post('/auth/login').send({ email: target, password: 'secret123' })).body.token;

  const forbidden = await request(app).get('/admin/audit').query({ email: target }).set('Authorization', `Bearer ${userToken}`);
  assert.equal(forbidden.status, 403);

  // Produce an attributable admin event (this suspends the target, so do it
  // after the plain-user check above).
  const adminStep = await stepUpFor(adminToken);
  assert.equal(
    (await request(app).post('/admin/user-status').set('Authorization', `Bearer ${adminToken}`).set('X-Step-Up', adminStep).send({ email: target, status: 'SUSPENDED' })).status,
    200,
  );

  const ok = await request(app).get('/admin/audit').query({ action: 'SET_USER_STATUS' }).set('Authorization', `Bearer ${adminToken}`);
  assert.equal(ok.status, 200);
  assert.equal(ok.body.data[0], 'AUDIT');
  assert.ok(Number(ok.body.data[1]) >= 1, 'reports a total');
  assert.match(ok.body.data[2], /SET_USER_STATUS/);
  assert.ok(ok.body.data[2].includes(admin), 'records the acting admin');
});

test('admin recovery endpoints are admin-only', async () => {
  const admin = `gw_rec_${Date.now()}@test.com`;
  const target = `gw_rec_t_${Date.now()}@test.com`;
  requireSeed(seedUser(admin, 'SUPER_ADMIN') && seedUser(target, 'USER'), 'seed recovery users');
  enableMfa(admin);
  const adminToken = await adminLoginFor(admin);
  const userToken = (await request(app).post('/auth/login').send({ email: target, password: 'secret123' })).body.token;
  const adminStep = await stepUpFor(adminToken);
  const userStep = await stepUpFor(userToken);

  assert.equal((await request(app).post('/admin/unlock').set('Authorization', `Bearer ${userToken}`).set('X-Step-Up', userStep).send({ email: target })).status, 403);
  assert.deepEqual((await request(app).post('/admin/unlock').set('Authorization', `Bearer ${adminToken}`).set('X-Step-Up', adminStep).send({ email: target })).body.data, ['ACCOUNT_UNLOCKED']);
  assert.deepEqual((await request(app).post('/admin/mfa-reset').set('Authorization', `Bearer ${adminToken}`).set('X-Step-Up', adminStep).send({ email: target })).body.data, ['MFA_RESET']);
});

test('admin hold lifecycle is admin-only', async () => {
  const admin = `gw_hold_${Date.now()}@test.com`;
  const target = `gw_hold_t_${Date.now()}@test.com`;
  requireSeed(seedUser(admin, 'SUPER_ADMIN') && seedUser(target, 'USER'), 'seed hold users');
  enableMfa(admin);
  const adminToken = await adminLoginFor(admin);
  const userToken = (await request(app).post('/auth/login').send({ email: target, password: 'secret123' })).body.token;
  requireSeed(seedAccount(target, '100.00'), 'seed target account');
  const adminStep = await stepUpFor(adminToken);
  const userStep = await stepUpFor(userToken);
  const auth = { Authorization: `Bearer ${adminToken}`, 'X-Step-Up': adminStep };

  // A non-admin cannot place a hold, even with a step-up proof.
  assert.equal((await request(app).post('/admin/holds').set('Authorization', `Bearer ${userToken}`).set('X-Step-Up', userStep).send({ email: target, amount: '10.00' })).status, 403);

  const placed = await request(app).post('/admin/holds').set(auth).send({ email: target, amount: '10.00', reason: 'review' });
  assert.equal(placed.status, 200);
  assert.equal(placed.body.data[0], 'HOLD_PLACED');
  assert.match(placed.body.data[1], /^[0-9]+$/);
  const holdId = placed.body.data[1];

  // Held funds are no longer spendable.
  const denied = await request(app).post('/wallet/transfer').set('Authorization', `Bearer ${userToken}`).set('Idempotency-Key', `hold-${Date.now()}`).send({ to: 'receiver@test.com', amount: '95.00' });
  assert.equal(denied.status, 409);
  assert.equal(denied.body.error, 'INSUFFICIENT_FUNDS');

  const released = await request(app).post('/admin/holds/release').set(auth).send({ holdId });
  assert.deepEqual(released.body.data, ['HOLD_RELEASED']);
  const rerelease = await request(app).post('/admin/holds/release').set(auth).send({ holdId });
  assert.equal(rerelease.status, 404);
  assert.equal(rerelease.body.error, 'UNKNOWN_TRANSACTION');
});

test('reconciliation runs record results and resolve exceptions', async () => {
  const admin = `gw_rec_${Date.now()}@test.com`;
  const target = `gw_rect_${Date.now()}@test.com`;
  requireSeed(seedUser(admin, 'SUPER_ADMIN') && seedUser(target, 'USER'), 'seed reconcile users');
  enableMfa(admin);
  const adminToken = await adminLoginFor(admin);
  const userToken = (await request(app).post('/auth/login').send({ email: target, password: 'secret123' })).body.token;
  requireSeed(seedAccount(target, '100.00'), 'seed target account');
  const adminStep = await stepUpFor(adminToken);
  const userStep = await stepUpFor(userToken);
  const auth = { Authorization: `Bearer ${adminToken}`, 'X-Step-Up': adminStep };

  // A non-admin cannot run a recorded reconciliation.
  assert.equal((await request(app).post('/admin/reconcile/run').set('Authorization', `Bearer ${userToken}`).set('X-Step-Up', userStep).send({})).status, 403);

  // Drift the target balance directly so this run must find it.
  requireSeed(runSql(`UPDATE accounts SET balance = 999.00 WHERE user_id = (SELECT id FROM users WHERE email = '${target}')`), 'drift the balance');
  const run = await request(app).post('/admin/reconcile/run').set(auth).send({ trigger: 'MANUAL' });
  assert.equal(run.status, 200);
  assert.equal(run.body.data[0], 'RUN_RECORDED');
  const runId = run.body.data[1];
  assert.match(runId, /^[0-9]+$/);
  assert.ok(Number(run.body.data[2]) >= 1, 'run reports its mismatches');

  const runs = await request(app).get('/admin/reconcile/runs').set('Authorization', `Bearer ${adminToken}`).query({ limit: '10' });
  assert.equal(runs.status, 200);
  assert.equal(runs.body.data[0], 'RUNS');
  assert.ok(runs.body.data.slice(2).join(';').includes(`MANUAL`), 'the run is listed');

  const open = await request(app).get('/admin/reconcile/exceptions').set('Authorization', `Bearer ${adminToken}`).query({ status: 'OPEN' });
  assert.equal(open.status, 200);
  assert.equal(open.body.data[0], 'EXCEPTIONS');
  const mine = open.body.data.slice(2).join(';').split(';').filter((r) => r.includes(`:${runId}:`));
  assert.ok(mine.length >= 1, 'the run produced an open finding');
  const findingId = mine[0].split(':')[0];

  const ack = await request(app).post('/admin/reconcile/acknowledge').set(auth).send({ findingId });
  assert.deepEqual(ack.body.data, ['EXCEPTION_ACKNOWLEDGED']);
  const resolve = await request(app).post('/admin/reconcile/resolve').set(auth).send({ findingId, note: 'opening balance corrected' });
  assert.deepEqual(resolve.body.data, ['EXCEPTION_RESOLVED']);

  const resolved = await request(app).get('/admin/reconcile/exceptions').set('Authorization', `Bearer ${adminToken}`).query({ status: 'RESOLVED' });
  assert.ok(resolved.body.data.slice(2).join(';').includes(`${findingId}:${runId}`), 'resolution is listed with its run');
  const closed = await request(app).post('/admin/reconcile/resolve').set(auth).send({ findingId, note: 'again' });
  assert.equal(closed.status, 404);
  assert.equal(closed.body.error, 'UNKNOWN_TRANSACTION');
});

test('privileged admin writes require a fresh step-up', async () => {
  const admin = `gw_su_${Date.now()}@test.com`;
  const target = `gw_su_t_${Date.now()}@test.com`;
  requireSeed(seedUser(admin, 'SUPER_ADMIN') && seedUser(target, 'USER'), 'seed step-up users');
  enableMfa(admin);
  const adminToken = await adminLoginFor(admin);

  // No step-up proof -> refused before the business action runs.
  assert.equal((await request(app).post('/admin/user-status').set('Authorization', `Bearer ${adminToken}`).send({ email: target, status: 'SUSPENDED' })).status, 401);

  // A wrong password cannot mint a proof.
  assert.equal((await request(app).post('/auth/step-up').set('Authorization', `Bearer ${adminToken}`).send({ password: 'nope' })).status, 401);

  const step = await stepUpFor(adminToken);
  assert.ok(step);

  // A step-up proof is not an access token.
  assert.equal((await request(app).get(`/users/${target}`).set('Authorization', `Bearer ${step}`)).status, 401);

  // With the proof the privileged write succeeds.
  assert.deepEqual(
    (await request(app).post('/admin/user-status').set('Authorization', `Bearer ${adminToken}`).set('X-Step-Up', step).send({ email: target, status: 'SUSPENDED' })).body.data,
    ['STATUS_CHANGED'],
  );
});

test('an admin without MFA is prompted to enrol at login', async () => {
  const admin = `gw_enr_${Date.now()}@test.com`;
  requireSeed(seedUser(admin, 'SUPER_ADMIN'), 'seed a SUPER_ADMIN');

  const login = await request(app).post('/auth/login').send({ email: admin, password: 'secret123' });
  assert.equal(login.status, 200);
  assert.equal(login.body.mfaEnrollmentRequired, true, 'login flags that MFA enrolment is required');
  const token = login.body.token;

  // Until enrolled, a step-up (needed for privileged writes) is refused.
  assert.equal((await request(app).post('/auth/step-up').set('Authorization', `Bearer ${token}`).send({ password: 'secret123' })).status, 401);

  // Enrol, then refresh: the prompt clears.
  const enroll = await request(app).post('/mfa/enroll').set('Authorization', `Bearer ${token}`).send({ email: admin });
  assert.equal(enroll.status, 200);
  assert.equal((await request(app).post('/mfa/confirm').set('Authorization', `Bearer ${token}`).send({ email: admin, code: totp(enroll.body.secret) })).status, 200);
  const refreshed = await request(app).post('/auth/refresh').send({ refreshToken: login.body.refreshToken });
  assert.equal(refreshed.status, 200);
  assert.notEqual(refreshed.body.mfaEnrollmentRequired, true, 'prompt clears once MFA is enabled');
});

test('reusing an idempotency key with different details is a conflict', async () => {
  const em = `gw_idem_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Idem User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  requireSeed(seedAccount(em, '500.00'), 'seed an account');

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

test('an in-progress intent blocks a same-key transfer, then replays once committed', async () => {
  const em = `gw_inprog_${Date.now()}@test.com`;
  const to = 'receiver@test.com';
  const amount = '1.00';
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'InProg User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  requireSeed(seedAccount(em, '500.00'), 'seed an account');

  const key = `gw-inprog-${Date.now()}`;
  // Same key and details already in flight (PENDING): another attempt holds it.
  requireSeed(runSql(`INSERT INTO pending_transactions (txn_ref, from_email, to_email, amount, status) VALUES ('${key}','${em}','${to}',${amount},'PENDING')`), 'seed a pending intent');

  const blocked = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', key)
    .send({ to, amount });
  assert.equal(blocked.status, 409);
  assert.equal(blocked.body.error, 'TRANSFER_IN_PROGRESS');

  // Once the original attempt commits, the same key is a replay (no movement).
  assert.ok(runSql(`UPDATE pending_transactions SET status='COMMITTED' WHERE txn_ref='${key}' AND from_email='${em}'`));
  const replay = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', key)
    .send({ to, amount });
  assert.equal(replay.status, 200);

  runSql(`DELETE FROM pending_transactions WHERE txn_ref='${key}'`);
});

test('transfer amount is decided by COBOL, not the gateway shape', async () => {
  const em = `gw_amt_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Amt User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  requireSeed(seedAccount(em, '100.00'), 'seed an account');

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

  // The gateway forwards up-to-4dp amounts; COBOL enforces the currency's
  // own precision (USD prec 2 refuses three decimals — core authority).
  const milli = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', `milli-${Date.now()}`)
    .send({ to: 'receiver@test.com', amount: '1.234' });
  assert.equal(milli.status, 400);
  assert.equal(milli.body.error, 'INVALID_AMOUNT');
});

test('the list page size is bounded', async () => {
  requireSeed(seedUser('gw_admin_limit@test.com', 'SUPER_ADMIN'), 'seed a SUPER_ADMIN');
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

test('a large list is not truncated at 500 bytes', async () => {
  requireSeed(seedUser('gw_admin_bulk@test.com', 'SUPER_ADMIN'), 'seed a SUPER_ADMIN');
  requireSeed(seedManyUsers('gw_bulk_', 25), 'seed bulk users');
  const token = (await request(app).post('/auth/login').send({ email: 'gw_admin_bulk@test.com', password: 'secret123' })).body.token;

  const res = await request(app).get('/users?limit=100').set('Authorization', `Bearer ${token}`);
  assert.equal(res.status, 200);
  // The 25th bulk user sits well past 500 bytes; it survives the multi-record output.
  assert.ok(JSON.stringify(res.body.users).includes('gw_bulk_25@test.com'));
});

test('one access token can be revoked without affecting another session', async () => {
  const em = `gw_deny_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Deny User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });

  const first = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  const second = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;

  const revoked = await request(app).post('/auth/revoke').set('Authorization', `Bearer ${first}`);
  assert.equal(revoked.status, 200);

  const gone = await request(app).get(`/users/${em}`).set('Authorization', `Bearer ${first}`);
  assert.equal(gone.status, 401);
  assert.equal(gone.body.error, 'TOKEN_REVOKED');

  // The other session is untouched (this is per-token, not per-user).
  assert.equal((await request(app).get(`/users/${em}`).set('Authorization', `Bearer ${second}`)).status, 200);
});

test('audit archiving is admin-only', async () => {
  requireSeed(seedUser('gw_admin_archive@test.com', 'SUPER_ADMIN'), 'seed a SUPER_ADMIN');
  enableMfa('gw_admin_archive@test.com');
  const adminToken = await adminLoginFor('gw_admin_archive@test.com');

  const em = `gw_arch_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Arch User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const userToken = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  const adminStep = await stepUpFor(adminToken);
  const userStep = await stepUpFor(userToken);

  const denied = await request(app).post('/admin/audit/archive').set('Authorization', `Bearer ${userToken}`).set('X-Step-Up', userStep).send({ days: 3650 });
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error, 'FORBIDDEN');

  const ok = await request(app).post('/admin/audit/archive').set('Authorization', `Bearer ${adminToken}`).set('X-Step-Up', adminStep).send({ days: 3650 });
  assert.equal(ok.status, 200);
  assert.deepEqual(ok.body.data, ['ARCHIVED']);
});

test('password reset and change over HTTP', async () => {
  const em = `gw_pw_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'PW User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const first = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });
  const oldToken = first.body.token;

  const forgot = await request(app).post('/auth/forgot').send({ email: em });
  assert.equal(forgot.status, 200);
  assert.deepEqual(forgot.body.data, ['CODE_SENT']);
  const code = getVerificationCode(em, 'PASSWORD_RESET');
  assert.match(code, /^\d{6}$/);

  const reset = await request(app).post('/auth/reset-password').send({ email: em, code, password: 'reset1234' });
  assert.equal(reset.status, 200);
  assert.deepEqual(reset.body.data, ['PASSWORD_RESET']);

  // Reset revoked the sessions: the old access token no longer works.
  assert.equal((await request(app).get(`/users/${em}`).set('Authorization', `Bearer ${oldToken}`)).status, 401);
  assert.equal((await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).status, 401);

  const second = await request(app).post('/auth/login').send({ email: em, password: 'reset1234' });
  assert.equal(second.status, 200);
  const changed = await request(app)
    .post('/profile/password')
    .set('Authorization', `Bearer ${second.body.token}`)
    .send({ email: em, currentPassword: 'reset1234', newPassword: 'final1234' });
  assert.equal(changed.status, 200);
  assert.deepEqual(changed.body.data, ['PASSWORD_CHANGED']);
  assert.equal((await request(app).post('/auth/login').send({ email: em, password: 'final1234' })).status, 200);
});

test('resend verification reuses the pending code inside the cooldown', async () => {
  const em = `gw_resend_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Resend', dob: '1990-01-01' });
  assert.equal(s.status, 200);
  // Login before verification is rejected.
  assert.equal((await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).status, 403);

  const resend = await request(app).post('/auth/resend').send({ email: em });
  assert.equal(resend.status, 200);
  assert.deepEqual(resend.body.data, ['CODE_SENT']);

  const code = getVerificationCode(em, 'SIGNUP');
  assert.match(code, /^\d{6}$/);
  assert.equal((await request(app).post('/auth/verify').send({ email: em, code })).status, 200);
  assert.equal((await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).status, 200);
});

test('login and signup do not enumerate accounts', async () => {
  const em = `gw_enum_${Date.now()}@test.com`;
  // Signing up twice yields the same neutral response.
  const a = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Enum', dob: '1990-01-01' });
  const b = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Enum', dob: '1990-01-01' });
  assert.equal(a.status, 200);
  assert.equal(b.status, 200);
  assert.deepEqual(a.body, b.body);

  // An unknown account and a wrong password are indistinguishable.
  const unknown = await request(app).post('/auth/login').send({ email: `ghost_${Date.now()}@test.com`, password: 'secret123' });
  const wrong = await request(app).post('/auth/login').send({ email: em, password: 'wrongpass1' });
  assert.equal(unknown.status, 401);
  assert.equal(wrong.status, 401);
  assert.deepEqual(unknown.body, wrong.body);
});

test('verification code guessing is capped', async () => {
  const em = `gw_cap_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Cap', dob: '1990-01-01' });
  const code = getVerificationCode(em, 'SIGNUP');
  for (let i = 0; i < 5; i++) {
    assert.equal((await request(app).post('/auth/verify').send({ email: em, code: '000000' })).status, 400);
  }
  // The code is burned: even the right one is rejected now.
  assert.equal((await request(app).post('/auth/verify').send({ email: em, code })).status, 400);
  // A resend issues a working code.
  await request(app).post('/auth/resend').send({ email: em });
  const fresh = getVerificationCode(em, 'SIGNUP');
  assert.equal((await request(app).post('/auth/verify').send({ email: em, code: fresh })).status, 200);
});

test('locked account does not leak through wrong guesses', async () => {
  const em = `gw_lock_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Lock', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  for (let i = 0; i < 3; i++) {
    await request(app).post('/auth/login').send({ email: em, password: 'wrongpass1' });
  }
  // Locked: a wrong password stays indistinguishable (401); the owner who
  // knows the password is told (423).
  assert.equal((await request(app).post('/auth/login').send({ email: em, password: 'wrongpass1' })).status, 401);
  assert.equal((await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).status, 423);
});

test('MFA enrol, enforce at login, disable over HTTP', async () => {
  const em = `gw_mfa_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Mfa', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const login = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });
  const auth = { Authorization: `Bearer ${login.body.token}` };

  const enroll = await request(app).post('/mfa/enroll').set(auth).send({ email: em });
  assert.equal(enroll.status, 200);
  assert.match(enroll.body.secret, /^[A-Z2-7]{32}$/);
  assert.ok(enroll.body.otpauth.startsWith('otpauth://totp/'));

  assert.equal((await request(app).post('/mfa/confirm').set(auth).send({ email: em, code: '000000' })).status, 401);
  assert.deepEqual((await request(app).post('/mfa/confirm').set(auth).send({ email: em, code: totp(enroll.body.secret) })).body.data, ['MFA_ENABLED']);

  assert.equal((await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).status, 401);
  assert.equal((await request(app).post('/auth/login').send({ email: em, password: 'secret123', mfaCode: totp(enroll.body.secret) })).status, 200);

  assert.deepEqual((await request(app).post('/mfa/disable').set(auth).send({ email: em, code: totp(enroll.body.secret) })).body.data, ['MFA_DISABLED']);
  assert.equal((await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).status, 200);
});

test('session listing and revoke-all over HTTP', async () => {
  const em = `gw_sess_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Sess', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const login = await request(app).post('/auth/login').set('User-Agent', 'gw-test-agent/1.0').send({ email: em, password: 'secret123' });
  const auth = { Authorization: `Bearer ${login.body.token}` };

  const list = await request(app).get('/sessions').query({ email: em }).set(auth);
  assert.equal(list.status, 200);
  assert.equal(list.body.data[0], 'SESSIONS');
  assert.ok(list.body.data[1].length > 0, 'lists the active refresh session');
  assert.match(list.body.data[1], /current/, 'marks the calling device as the current session');
  assert.match(list.body.data[1], /gw-test-agent/, 'records the client user-agent');

  assert.deepEqual((await request(app).post('/sessions/revoke-all').set(auth).send({ email: em })).body.data, ['SESSIONS_REVOKED']);
  // The version bump kills the access token we were using.
  assert.equal((await request(app).get('/profile').query({ email: em }).set(auth)).status, 401);
});

test('transfers from a frozen account are rejected (409)', async () => {
  const em = `gw_frozen_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Frozen', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const login = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });
  const auth = { Authorization: `Bearer ${login.body.token}` };
  seedAccount(em, '1000.00');
  runSql(`UPDATE accounts a JOIN users u ON a.user_id=u.id SET a.status='FROZEN' WHERE u.email='${em}'`);

  const res = await request(app)
    .post('/wallet/transfer')
    .set(auth)
    .set('Idempotency-Key', `frozen-${Date.now()}`)
    .send({ to: 'receiver@test.com', amount: '10.00' });
  assert.equal(res.status, 409);
  assert.equal(res.body.error, 'ACCOUNT_FROZEN');

  // Unfreezing lets it through again.
  runSql(`UPDATE accounts a JOIN users u ON a.user_id=u.id SET a.status='ACTIVE' WHERE u.email='${em}'`);
  const ok = await request(app)
    .post('/wallet/transfer')
    .set(auth)
    .set('Idempotency-Key', `active-${Date.now()}`)
    .send({ to: 'receiver@test.com', amount: '10.00' });
  assert.equal(ok.status, 200);
});

test('transfer without an idempotency key is rejected', async () => {
  const em = `gw_nokey_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'NoKey', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  seedAccount(em, '100.00');

  const res = await request(app)
    .post('/wallet/transfer')
    .set('Authorization', `Bearer ${token}`)
    .send({ to: 'receiver@test.com', amount: '1.00' });
  assert.equal(res.status, 400);
  assert.equal(res.body.error, 'INVALID_PARAMETER');
});

test('transfer over the per-transaction limit is rejected', async () => {
  const em = `gw_limit_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Limit', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  seedAccount(em, '1000.00');

  const prev = process.env.TRANSFER_MAX_PER_TXN;
  process.env.TRANSFER_MAX_PER_TXN = '1';
  try {
    const res = await request(app)
      .post('/wallet/transfer')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', `lim-${Date.now()}`)
      .send({ to: 'receiver@test.com', amount: '2.00' });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'LIMIT_EXCEEDED');
  } finally {
    if (prev === undefined) delete process.env.TRANSFER_MAX_PER_TXN;
    else process.env.TRANSFER_MAX_PER_TXN = prev;
  }
});

test('transfer status and reversal over HTTP', async () => {
  const em = `gw_rev_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Rev', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  const auth = { Authorization: `Bearer ${token}` };
  seedAccount(em, '1000.00');

  const key = `rev-${Date.now()}`;
  assert.equal((await request(app).post('/wallet/transfer').set(auth).set('Idempotency-Key', key).send({ to: 'receiver@test.com', amount: '10.00' })).status, 200);

  const status = await request(app).get(`/transactions/${key}`).set(auth);
  assert.equal(status.status, 200);
  assert.equal(status.body.data[0], 'TRANSFER');
  assert.equal(status.body.data[1], 'COMMITTED');

  const admin = `gw_revadm_${Date.now()}@test.com`;
  if (!seedUser(admin, 'SUPER_ADMIN')) return;
  enableMfa(admin);
  const adminToken = await adminLoginFor(admin);
  const adminStep = await stepUpFor(adminToken);
  // An admin can target a specific sender.
  const scoped = await request(app).get(`/transactions/${key}`).query({ sender: em }).set('Authorization', `Bearer ${adminToken}`);
  assert.equal(scoped.status, 200);
  assert.equal(scoped.body.data[2], em);
  const rev = await request(app).post(`/transactions/${key}/reverse`).set('Authorization', `Bearer ${adminToken}`).set('X-Step-Up', adminStep).send({});
  assert.equal(rev.status, 200);
  assert.deepEqual(rev.body.data, ['TRANSFER_REVERSED']);

  assert.equal((await request(app).get(`/transactions/${key}`).set(auth)).body.data[1], 'REVERSED');
});

test('cross-currency transfer falls back to the inverse rate', async () => {
  const em = `gw_fx_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Fx', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  const auth = { Authorization: `Bearer ${token}` };
  // Only an IDR account: the IDR->USD pair does not exist directly, so the
  // gateway/core must use the reciprocal of USD->IDR.
  runSql(`INSERT INTO accounts (user_id, currency_id, balance, status) SELECT id, 3, 100000.00, 'ACTIVE' FROM users WHERE email='${em}' AND NOT EXISTS (SELECT 1 FROM accounts a WHERE a.user_id=users.id)`);

  const key = `fx-${Date.now()}`;
  const res = await request(app).post('/wallet/transfer').set(auth).set('Idempotency-Key', key).send({ to: 'receiver@test.com', amount: '15700' });
  assert.equal(res.status, 200);
  const status = await request(app).get(`/transactions/${key}`).set(auth);
  assert.equal(status.body.data[1], 'COMMITTED');
});

test('transfer selects the sender account by currency', async () => {
  const em = `gw_mc_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Mc', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  const auth = { Authorization: `Bearer ${token}` };
  runSql(`INSERT INTO accounts (user_id,currency_id,balance,status) SELECT id,1,1000.00,'ACTIVE' FROM users WHERE email='${em}' AND NOT EXISTS (SELECT 1 FROM accounts a WHERE a.user_id=users.id)`);
  runSql(`INSERT INTO accounts (user_id,currency_id,balance,status) SELECT id,2,1000.00,'ACTIVE' FROM users WHERE email='${em}' AND NOT EXISTS (SELECT 1 FROM accounts a WHERE a.user_id=users.id AND a.currency_id=2)`);

  const res = await request(app).post('/wallet/transfer').set(auth).set('Idempotency-Key', `mc-${Date.now()}`).send({ to: 'receiver@test.com', amount: '100.00', fromCurrency: 'EUR' });
  assert.equal(res.status, 200);

  const bad = await request(app).post('/wallet/transfer').set(auth).set('Idempotency-Key', `mcbad-${Date.now()}`).send({ to: 'receiver@test.com', amount: '1.00', fromCurrency: 'JPY' });
  assert.equal(bad.status, 404);
});

test('profile is structured and works without accounts', async () => {
  const em = `gw_prof_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Prof', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;

  const res = await request(app).get('/profile').query({ email: em }).set('Authorization', `Bearer ${token}`);
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data, ['PROFILE']);
  assert.equal(res.body.profile.email, em);
  assert.equal(res.body.profile.status, 'VERIFIED');
  assert.deepEqual(res.body.accounts, []);

  requireSeed(seedAccount(em, '250.00'), 'seed profile account');
  const withAcct = await request(app).get('/profile').query({ email: em }).set('Authorization', `Bearer ${token}`);
  assert.equal(withAcct.body.accounts.length, 1);
  assert.equal(withAcct.body.accounts[0].balance, withAcct.body.accounts[0].available);
  assert.equal(withAcct.body.accounts[0].status, 'ACTIVE');
});

test('email-change request is neutral for a taken address', async () => {
  const em = `gw_enum_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Enum', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  const auth = { Authorization: `Bearer ${token}` };

  const taken = `gw_taken_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: taken, password: 'secret123', name: 'Taken', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: taken, code: getVerificationCode(taken) });

  const a = await request(app).post('/profile/email/request').set(auth).send({ email: em, newEmail: taken, password: 'secret123' });
  const b = await request(app).post('/profile/email/request').set(auth).send({ email: em, newEmail: `gw_free_${Date.now()}@test.com`, password: 'secret123' });
  assert.equal(a.status, 200);
  assert.equal(b.status, 200);
  assert.deepEqual(a.body, b.body); // identical neutral response
  assert.equal(getVerificationCode(taken, 'EMAIL_CHANGE'), ''); // no code minted for the taken address
});

test('PATCH /profile updates the name', async () => {
  const em = `gw_up_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Before', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  const auth = { Authorization: `Bearer ${token}` };

  const res = await request(app).patch('/profile').set(auth).send({ email: em, name: 'Updated Name' });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data, ['PROFILE_UPDATED']);
  assert.equal((await request(app).get('/profile').query({ email: em }).set(auth)).body.profile.name, 'Updated Name');
});

test('account lifecycle over HTTP', async () => {
  const em = `gw_lc_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Life', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  const auth = { Authorization: `Bearer ${token}` };

  assert.deepEqual((await request(app).post('/profile/deactivate').set(auth).send({ email: em })).body.data, ['ACCOUNT_DEACTIVATED']);
  assert.equal((await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.error, 'USER_CLOSED');

  const admin = `gw_lca_${Date.now()}@test.com`;
  if (!seedUser(admin, 'SUPER_ADMIN')) return;
  enableMfa(admin);
  const adminToken = await adminLoginFor(admin);
  const adm = { Authorization: `Bearer ${adminToken}`, 'X-Step-Up': await stepUpFor(adminToken) };
  assert.deepEqual((await request(app).post('/admin/user-status').set(adm).send({ email: em, status: 'SUSPENDED' })).body.data, ['STATUS_CHANGED']);
  const blocked = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });
  assert.equal(blocked.status, 403);
  assert.equal(blocked.body.error, 'USER_SUSPENDED');
});

test('user listing and record are structured', async () => {
  const admin = `gw_listadm_${Date.now()}@test.com`;
  if (!seedUser(admin, 'SUPER_ADMIN')) return;
  enableMfa(admin);
  const adminToken = await adminLoginFor(admin);
  const adm = { Authorization: `Bearer ${adminToken}` };

  const list = await request(app).get('/users').query({ limit: 5, role: 'SUPER_ADMIN' }).set(adm);
  assert.equal(list.status, 200);
  assert.equal(list.body.data[0], 'USERS');
  assert.equal(typeof list.body.total, 'number');
  assert.ok(Array.isArray(list.body.users));
  assert.ok(list.body.users.every((u) => u.role === 'SUPER_ADMIN'));

  const rec = await request(app).get('/users/sender@test.com').set(adm);
  assert.equal(rec.status, 200);
  assert.equal(rec.body.data[0], 'USER');
  assert.equal(rec.body.user.email, 'sender@test.com');
});

test('email-change confirm reports a taken address (race)', async () => {
  const em = `gw_race_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Race', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const token = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;
  const auth = { Authorization: `Bearer ${token}` };
  const ne = `gw_racenew_${Date.now()}@test.com`;

  assert.equal((await request(app).post('/profile/email/request').set(auth).send({ email: em, newEmail: ne, password: 'secret123' })).status, 200);
  const code = getVerificationCode(ne, 'EMAIL_CHANGE');
  // Someone else takes the address between the request and the confirm.
  runSql(`INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES ('${ne}','x','Taken','1990-01-01','VERIFIED','USER')`);

  const conf = await request(app).post('/profile/email/confirm').set(auth).send({ email: em, newEmail: ne, code });
  assert.equal(conf.status, 400);
  assert.equal(conf.body.error, 'EMAIL_EXISTS');
});

test('refresh rotates and a replay is rejected', async () => {
  const em = `gw_rot_${Date.now()}@test.com`;
  await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Rot', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const login = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });

  const first = await request(app).post('/auth/refresh').send({ refreshToken: login.body.refreshToken });
  assert.equal(first.status, 200);
  const rotated = first.body.refreshToken;
  assert.ok(rotated && rotated !== login.body.refreshToken);

  // Replaying the consumed token is reuse: rejected, and the whole family dies.
  assert.equal((await request(app).post('/auth/refresh').send({ refreshToken: login.body.refreshToken })).status, 401);
  assert.equal((await request(app).post('/auth/refresh').send({ refreshToken: rotated })).status, 401);
});

test('liveness and readiness probes', async () => {
  const live = await request(app).get('/live');
  assert.equal(live.status, 200);
  assert.equal(live.body.status, 'alive');

  const ready = await request(app).get('/ready');
  assert.equal(ready.status, 200);
  assert.equal(ready.body.status, 'ready');
  assert.equal(ready.body.checks.db, 'up');
  assert.ok(['up', 'off'].includes(ready.body.checks.pool));
  assert.ok(['configured', 'unset'].includes(ready.body.checks.mailer));
});

test('dual control gates designated operations', async () => {
  const maker = `gw_dc_mkr_${Date.now()}@test.com`;
  const checker = `gw_dc_chk_${Date.now()}@test.com`;
  const target = `gw_dc_tgt_${Date.now()}@test.com`;
  requireSeed(seedUser(maker, 'SUPER_ADMIN') && seedUser(checker, 'SUPER_ADMIN') && seedUser(target, 'USER'), 'seed dual-control users');
  enableMfa(maker);
  enableMfa(checker);
  const makerToken = await adminLoginFor(maker);
  const checkerToken = await adminLoginFor(checker);
  const userToken = (await request(app).post('/auth/login').send({ email: target, password: 'secret123' })).body.token;
  const makerStep = await stepUpFor(makerToken);
  const checkerStep = await stepUpFor(checkerToken);
  const userStep = await stepUpFor(userToken);
  const mkAuth = { Authorization: `Bearer ${makerToken}`, 'X-Step-Up': makerStep };
  const ckAuth = { Authorization: `Bearer ${checkerToken}`, 'X-Step-Up': checkerStep };
  requireSeed(runSql(`INSERT IGNORE INTO dual_control_operations (operation) VALUES ('CHANGE_ROLE')`), 'designate role changes');
  try {
    // A direct change is refused while the operation is designated.
    const direct = await request(app).post('/admin/role').set(mkAuth).send({ email: target, role: 'MANAGER' });
    assert.equal(direct.status, 403);
    assert.equal(direct.body.error, 'DUAL_CONTROL_REQUIRED');

    const placed = await request(app).post('/admin/requests').set(mkAuth).send({ operation: 'CHANGE_ROLE', target, detail: 'MANAGER' });
    assert.equal(placed.status, 200);
    assert.equal(placed.body.data[0], 'REQUEST_PLACED');
    const reqId = placed.body.data[1];

    // The maker cannot approve their own request.
    const self = await request(app).post('/admin/requests/approve').set(mkAuth).send({ requestId: reqId });
    assert.equal(self.status, 403);

    const approved = await request(app).post('/admin/requests/approve').set(ckAuth).send({ requestId: reqId });
    assert.deepEqual(approved.body.data, ['REQUEST_APPROVED']);

    const listed = await request(app).get('/admin/requests').set({ Authorization: `Bearer ${checkerToken}` }).query({ status: 'APPROVED' });
    assert.ok(listed.body.data.slice(2).join(';').includes(`${reqId}:CHANGE_ROLE`), 'the approved request is listed');
  } finally {
    requireSeed(runSql(`DELETE FROM maker_requests WHERE maker_email IN ('${maker}','${checker}'); DELETE FROM dual_control_operations WHERE operation = 'CHANGE_ROLE';`), 'undesignate role changes');
  }
});

test('verification codes flow through the outbox', async () => {
  const em = `gw_ob_${Date.now()}@test.com`;
  const admin = `gw_ob_adm_${Date.now()}@test.com`;
  requireSeed(seedUser(admin, 'SUPER_ADMIN'), 'seed outbox admin');
  const adminToken = (await request(app).post('/auth/login').send({ email: admin, password: 'secret123' })).body.token;

  const signup = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Outbox', dob: '1990-01-01' });
  assert.equal(signup.status, 200);

  // The signup queued a PENDING row, without exposing the code.
  const queued = await request(app).get('/admin/outbox').set('Authorization', `Bearer ${adminToken}`).query({ status: 'PENDING' });
  assert.equal(queued.status, 200);
  assert.equal(queued.body.data[0], 'OUTBOX');
  assert.ok(!JSON.stringify(queued.body).includes(getVerificationCode(em) ?? 'no-such-code'), 'the code is never exposed');
  assert.ok(queued.body.data.slice(2).join(';').includes(em), 'the signup row is queued');

  // The worker delivers it; the delivered code verifies the account.
  const dir = await mkdtemp(path.join(tmpdir(), 'gw-ob-'));
  try {
    const logFile = path.join(dir, 'outbox.log');
    const workerPath = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'src', 'outbox_worker.js');
    const runWorker = () => new Promise((resolve, reject) => {
      execFile('node', [workerPath, '--once', '--limit', '500'], {
        env: { ...process.env, OUTBOX_TRANSPORT: 'log', OUTBOX_LOG_FILE: logFile },
      }, (err, stdout) => (err ? reject(err) : resolve(stdout)));
    });
    // Other suites run in parallel and share the outbox; keep dispatching
    // until our row is delivered (bounded; residue is finite per run).
    let delivered = null;
    let dbgRounds = [];
    for (let r = 0; r < 8 && !delivered; r++) {
      const out = await runWorker();
      const lines = (await readFile(logFile, 'utf8')).trim().split('\n').map((x) => JSON.parse(x));
      delivered = lines.find((x) => x.to === em);
      dbgRounds.push({ r, newLines: lines.length, outLen: String(out).length });
      if (r === 7) console.log('DBG-OUTBOX-LOOP ' + JSON.stringify({ em, dbgRounds, totalLines: lines.length }));
    }
    assert.ok(delivered, 'our row was delivered');
    const verify = await request(app).post('/auth/verify').send({ email: em, code: delivered.text.match(/\d{6}/)[0] });
    assert.equal(verify.body.data[0], 'EMAIL_VERIFIED');
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('readiness reports 503 when the database is down', async () => {
  // A fresh app (fresh probe cache and limiter); the spawned COBOL process
  // inherits this process' environment, so a bogus DB name fails PING fast
  // (unknown database). Test files run in separate processes, so the swap
  // cannot disturb parallel suites.
  const app = buildApp();
  const saved = process.env.DB_NAME;
  process.env.DB_NAME = 'nonexistent_db_xyz';
  try {
    const res = await request(app).get('/ready');
    assert.equal(res.status, 503);
    assert.equal(res.body.status, 'not_ready');
    assert.equal(res.body.checks.db, 'down');
  } finally {
    if (saved === undefined) delete process.env.DB_NAME;
    else process.env.DB_NAME = saved;
  }
});

test('mfa backup codes and assisted recovery work end to end', async () => {
  const user = `gw_mfarec_${Date.now()}@test.com`;
  const admin = `gw_mfarec_adm_${Date.now()}@test.com`;
  requireSeed(seedUser(user, 'USER') && seedUser(admin, 'SUPER_ADMIN'), 'seed recovery users');
  enableMfa(user);
  enableMfa(admin);
  const userToken = (await request(app).post('/auth/login').send({ email: user, password: 'secret123', mfaCode: totp(TEST_MFA_SECRET) })).body.token;
  assert.ok(userToken);
  const adminToken = await adminLoginFor(admin);

  // Backup codes are issued once and work in place of TOTP.
  const gen = await request(app).post('/mfa/backup-codes').set('Authorization', `Bearer ${userToken}`).send({ email: user });
  assert.equal(gen.body.data[0], 'BACKUP_CODES');
  assert.equal(gen.body.codes.length, 8);
  const [first, second] = gen.body.codes;
  const blocked = await request(app).get('/admin/mfa-recovery').set('Authorization', `Bearer ${userToken}`);
  assert.equal(blocked.status, 403);

  const loginBackup = await request(app).post('/auth/login').send({ email: user, password: 'secret123', mfaCode: first });
  assert.equal(loginBackup.body.data[0], 'LOGIN_OK');
  const replay = await request(app).post('/auth/login').send({ email: user, password: 'secret123', mfaCode: first });
  assert.equal(replay.body.error, 'INVALID_MFA');

  // Assisted recovery: request, verify the emailed code, approve as admin.
  const req = await request(app).post('/mfa/recover').send({ email: user, password: 'secret123' });
  assert.deepEqual(req.body.data, ['CODE_SENT']);
  const code = getVerificationCode(user, 'MFA_RECOVERY');
  assert.ok(/^\d{6}$/.test(code));
  const confirm = await request(app).post('/mfa/recover/confirm').send({ email: user, code });
  assert.deepEqual(confirm.body.data, ['RECOVERY_VERIFIED']);
  const queue = await request(app).get('/admin/mfa-recovery').set('Authorization', `Bearer ${adminToken}`).query({ status: 'VERIFIED' });
  assert.equal(queue.body.data[0], 'RECOVERY_REQUESTS');
  const reqId = queue.body.data.find((r) => r.includes(user)).split(':')[0];
  assert.ok(reqId);

  // A non-admin cannot approve; the admin's step-up approval clears MFA.
  const userStep = await stepUpFor(userToken);
  assert.equal((await request(app).post('/admin/mfa-recovery/approve').set('Authorization', `Bearer ${userToken}`).set('X-Step-Up', userStep).send({ requestId: reqId })).status, 403);
  const adminStep = await stepUpFor(adminToken);
  const approved = await request(app).post('/admin/mfa-recovery/approve').set('Authorization', `Bearer ${adminToken}`).set('X-Step-Up', adminStep).send({ requestId: reqId });
  assert.deepEqual(approved.body.data, ['RECOVERY_APPROVED']);

  const after = await request(app).post('/auth/login').send({ email: user, password: 'secret123' });
  assert.equal(after.body.data[0], 'LOGIN_OK');
  // With MFA cleared the old codes are inert: plain login works, codes are ignored.
  const secondLogin = await request(app).post('/auth/login').send({ email: user, password: 'secret123', mfaCode: second });
  assert.equal(secondLogin.body.data[0], 'LOGIN_OK');
});

test('account statements show postings with opening and closing balances', async () => {
  const user = `gw_stmt_${Date.now()}@test.com`;
  const other = `gw_stmt_o_${Date.now()}@test.com`;
  requireSeed(seedUser(user, 'USER') && seedUser(other, 'USER'), 'seed statement users');
  requireSeed(seedAccount(user, '1000.00') && seedAccount(other, '1000.00'), 'seed statement accounts');
  // Fixture funding rows so the ledger backs the seeded balances.
  requireSeed(runSql(`INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description) SELECT 'GWSTMT_FUND',(SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${user}')),1000,'CREDIT',1,'E2E funding'`) && runSql(`INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description) SELECT 'GWSTMT_FUND',(SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${other}')),1000,'CREDIT',1,'E2E funding'`), 'seed funding legs');
  const userToken = (await request(app).post('/auth/login').send({ email: user, password: 'secret123' })).body.token;
  const otherToken = (await request(app).post('/auth/login').send({ email: other, password: 'secret123' })).body.token;
  assert.ok(userToken && otherToken);

  const ref = `gwstmt${Date.now()}`;
  const sent = await request(app).post('/wallet/transfer').set('Authorization', `Bearer ${userToken}`).send({ from: user, to: other, amount: '25.00', idempotencyKey: ref });
  assert.equal(sent.body.data[0], 'TRANSFER_OK');

  const stmt = await request(app).get('/statements').set('Authorization', `Bearer ${userToken}`).query({ email: user, currency: 'USD', limit: '50' });
  assert.equal(stmt.body.opening, '0.00');
  assert.equal(stmt.body.closing, '975.00');
  assert.equal(stmt.body.currency, 'USD');
  assert.equal(stmt.body.lines.length, 2);
  const out = stmt.body.lines.find((l) => l.side === 'DEBIT');
  assert.equal(out.ref, ref);
  assert.equal(out.source, 'TRANSFER');
  assert.equal(out.amount, '25.00');
  assert.equal(out.balanceAfter, '975.00');
  assert.equal(out.reversed, false);
  assert.equal(stmt.body.lines.at(-1).balanceAfter, stmt.body.closing);

  const counter = await request(app).get('/statements').set('Authorization', `Bearer ${otherToken}`).query({ email: other, currency: 'USD' });
  assert.equal(counter.body.closing, '1025.00');

  const page = await request(app).get('/statements').set('Authorization', `Bearer ${userToken}`).query({ email: user, currency: 'USD', limit: '1', offset: '1' });
  assert.equal(page.body.total, '2');
  assert.equal(page.body.lines.length, 1);

  // A stranger cannot read someone else's statement.
  const blocked = await request(app).get('/statements').set('Authorization', `Bearer ${otherToken}`).query({ email: user, currency: 'USD' });
  assert.equal(blocked.status, 403);
});

test('dispute tickets run the full lifecycle end to end', async () => {
  const user = `gw_dsp_${Date.now()}@test.com`;
  const admin = `gw_dsp_adm_${Date.now()}@test.com`;
  requireSeed(seedUser(user, 'USER') && seedUser(admin, 'SUPER_ADMIN'), 'seed dispute users');
  enableMfa(admin);
  const userToken = (await request(app).post('/auth/login').send({ email: user, password: 'secret123' })).body.token;
  assert.ok(userToken);
  const adminToken = await adminLoginFor(admin);

  // A customer opens a case about their own issue.
  const opened = await request(app).post('/disputes').set('Authorization', `Bearer ${userToken}`).send({ email: user, subject: 'Missing transfer', detail: 'Where is my money' });
  assert.equal(opened.body.data[0], 'DISPUTE_OPENED');
  const caseId = opened.body.caseId;
  assert.ok(caseId);

  // Notes accumulate; a stranger cannot read or write the case.
  const stranger = `gw_dsp_x_${Date.now()}@test.com`;
  requireSeed(seedUser(stranger, 'USER'), 'seed stranger');
  const strangerToken = (await request(app).post('/auth/login').send({ email: stranger, password: 'secret123' })).body.token;
  assert.equal((await request(app).get(`/disputes/${caseId}`).set('Authorization', `Bearer ${strangerToken}`).query({})).status, 403);
  assert.equal((await request(app).get('/disputes').set('Authorization', `Bearer ${strangerToken}`)).body.cases.length, 0);

  const noted = await request(app).post(`/disputes/${caseId}/notes`).set('Authorization', `Bearer ${userToken}`).send({ body: 'Extra info here' });
  assert.deepEqual(noted.body.data, ['DISPUTE_NOTED']);

  // The admin acknowledges (with a due date), then resolves with step-up.
  const adminStep = await stepUpFor(adminToken);
  const acked = await request(app).post(`/disputes/${caseId}/acknowledge`).set('Authorization', `Bearer ${adminToken}`).set('X-Step-Up', adminStep).send({ due: '2099-01-31' });
  assert.deepEqual(acked.body.data, ['DISPUTE_ACKNOWLEDGED']);
  const resolved = await request(app).post(`/disputes/${caseId}/resolve`).set('Authorization', `Bearer ${adminToken}`).set('X-Step-Up', adminStep).send({ resolution: 'Money returned' });
  assert.deepEqual(resolved.body.data, ['DISPUTE_RESOLVED']);

  // The customer sees the resolution and the full note history.
  const got = await request(app).get(`/disputes/${caseId}`).set('Authorization', `Bearer ${userToken}`);
  assert.equal(got.body.case.state, 'RESOLVED');
  assert.equal(got.body.case.resolution, 'Money returned');
  assert.equal(got.body.messages.length, 1);

  // The admin queue lists the case; terminal cases refuse new notes.
  const queue = await request(app).get('/disputes').set('Authorization', `Bearer ${adminToken}`).query({ status: 'RESOLVED' });
  assert.ok(queue.body.cases.some((c) => c.caseId === String(caseId) && c.state === 'RESOLVED'));
  const late = await request(app).post(`/disputes/${caseId}/notes`).set('Authorization', `Bearer ${userToken}`).send({ body: 'Too late' });
  assert.equal(late.body.error, 'INVALID_STATUS');
});
