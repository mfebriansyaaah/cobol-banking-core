import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import request from 'supertest';
import { buildApp } from '../src/app.js';
import { seedUser, seedAccount, seedManyUsers, getVerificationCode, runSql } from './support.js';

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
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64BE(BigInt(Math.floor(Date.now() / 30000)));
  const h = createHmac('sha1', fromBase32(secret)).update(buf).digest();
  const o = h[h.length - 1] & 0xf;
  const bin = ((h[o] & 0x7f) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3];
  return String(bin % 1000000).padStart(6, '0');
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

test('audit archiving is admin-only', async (t) => {
  if (!seedUser('gw_admin_archive@test.com', 'SUPER_ADMIN')) return t.skip('mysql unavailable');
  const adminToken = (await request(app).post('/auth/login').send({ email: 'gw_admin_archive@test.com', password: 'secret123' })).body.token;

  const em = `gw_arch_${Date.now()}@test.com`;
  const s = await request(app).post('/auth/signup').send({ email: em, password: 'secret123', name: 'Arch User', dob: '1990-01-01' });
  await request(app).post('/auth/verify').send({ email: em, code: getVerificationCode(em) });
  const userToken = (await request(app).post('/auth/login').send({ email: em, password: 'secret123' })).body.token;

  const denied = await request(app).post('/admin/audit/archive').set('Authorization', `Bearer ${userToken}`).send({ days: 3650 });
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error, 'FORBIDDEN');

  const ok = await request(app).post('/admin/audit/archive').set('Authorization', `Bearer ${adminToken}`).send({ days: 3650 });
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

test('resend verification issues a fresh code', async () => {
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
  const login = await request(app).post('/auth/login').send({ email: em, password: 'secret123' });
  const auth = { Authorization: `Bearer ${login.body.token}` };

  const list = await request(app).get('/sessions').query({ email: em }).set(auth);
  assert.equal(list.status, 200);
  assert.equal(list.body.data[0], 'SESSIONS');
  assert.ok(list.body.data[1].length > 0, 'lists the active refresh session');

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
  const adminToken = (await request(app).post('/auth/login').send({ email: admin, password: 'secret123' })).body.token;
  // An admin can target a specific sender.
  const scoped = await request(app).get(`/transactions/${key}`).query({ sender: em }).set('Authorization', `Bearer ${adminToken}`);
  assert.equal(scoped.status, 200);
  assert.equal(scoped.body.data[2], em);
  const rev = await request(app).post(`/transactions/${key}/reverse`).set('Authorization', `Bearer ${adminToken}`).send({});
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
