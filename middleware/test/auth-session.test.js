import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { buildApp } from '../src/app.js';
import { resetPool } from '../src/pool.js';
import { getVerificationCode, testNamespace, uniqueEmail, cleanupNamespace } from './support.js';

const app = buildApp();

// Per-file fixture namespace with cleanup: without this, users leak
// (no other suite cleans the sess_* pattern) and gateway.test.js's
// broad gw_% cleanup deletes these users mid-run.
const NS = testNamespace('sess');
const U = (tag) => uniqueEmail(NS, tag);
after(() => {
  cleanupNamespace(NS);
});
// Drop pooled COBOL workers so the process can exit when this file runs
// under pool mode (preload.gateway): spawned --serve children keep the
// event loop alive (gateway.test.js and endpoints.test.js do the same).
after(() => resetPool());

async function loginNewUser() {
  // Unique per call: two tests share this helper, and re-signup of an
  // already-verified user returns 200 without issuing a new code, so a
  // shared email would leave the second caller with no usable code.
  loginNewUser.n = (loginNewUser.n || 0) + 1;
  const email = U(`sess${loginNewUser.n}`);
  const signup = await request(app)
    .post('/auth/signup')
    .send({ email, password: 'secret123', name: 'Session User', dob: '1990-01-01' });
  assert.equal(signup.status, 200);
  // The code is read back over a separate mysql client while other test files
  // hammer the same database; a transient read failure used to surface later
  // as a misleading 401 on login. Retry the read bounded, then fail fast with
  // the real step attached.
  let code = '';
  for (let i = 0; i < 5 && !code; i += 1) {
    code = getVerificationCode(email);
    if (!code) await new Promise((r) => setTimeout(r, 100));
  }
  assert.match(code, /^\d{6}$/, 'verification code readable');
  const verify = await request(app).post('/auth/verify').send({ email, code });
  assert.equal(verify.status, 200);
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
  const email = U('rev');
  await request(app)
    .post('/auth/signup')
    .send({ email, password: 'secret123', name: 'Revoke User', dob: '1990-01-01' });
  await request(app)
    .post('/auth/verify')
    .send({ email, code: getVerificationCode(email) });
  const login = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  const auth = { Authorization: `Bearer ${login.body.token}` };

  assert.equal((await request(app).get(`/users/${email}`).set(auth)).status, 200);

  const out = await request(app).post('/auth/logout').set(auth).send({ refreshToken: login.body.refreshToken });
  assert.equal(out.status, 200);

  // The same access token is now rejected before it would have expired.
  const after = await request(app).get(`/users/${email}`).set(auth);
  assert.equal(after.status, 401);
  assert.equal(after.body.error, 'TOKEN_REVOKED');
});

test('logout is per-device and leaves other sessions alone', async () => {
  const email = U('dev');
  await request(app)
    .post('/auth/signup')
    .send({ email, password: 'secret123', name: 'Device User', dob: '1990-01-01' });
  await request(app)
    .post('/auth/verify')
    .send({ email, code: getVerificationCode(email) });
  const a = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  const b = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  const authA = { Authorization: `Bearer ${a.body.token}` };
  const authB = { Authorization: `Bearer ${b.body.token}` };

  const out = await request(app).post('/auth/logout').set(authA).send({ refreshToken: a.body.refreshToken });
  assert.equal(out.status, 200);

  // Device A is fully logged out (access token denied, refresh revoked).
  assert.equal((await request(app).get(`/users/${email}`).set(authA)).status, 401);
  assert.equal((await request(app).post('/auth/refresh').send({ refreshToken: a.body.refreshToken })).status, 401);

  // Device B is untouched.
  assert.equal((await request(app).get(`/users/${email}`).set(authB)).status, 200);
  assert.equal((await request(app).post('/auth/refresh').send({ refreshToken: b.body.refreshToken })).status, 200);
});
