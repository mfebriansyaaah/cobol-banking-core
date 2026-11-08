// Trust-boundary tests: the gateway derives KYC/screening/risk/OTP values
// server-side. Client-supplied verdicts, hashes, and signals are overwritten
// by derivations (or rejected), and OTP codes never appear in responses.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import request from 'supertest';
import { buildApp } from '../src/app.js';
import { resetPool } from '../src/pool.js';
import { seedUser, requireSeed, queryScalar, testNamespace, uniqueEmail, cleanupNamespace } from './support.js';

process.env.NIK_HMAC_SECRET ??= 'test-hmac-secret-trust-boundary';

const app = buildApp();
const NS = testNamespace('tb');
const U = (tag) => uniqueEmail(NS, tag);
after(() => {
  cleanupNamespace(NS);
});
after(() => resetPool());

async function userToken(email) {
  requireSeed(seedUser(email), `seed ${email}`);
  const r = await request(app).post('/auth/login').send({ email, password: 'secret123' });
  assert.equal(r.status, 200);
  return r.body.token;
}

const VALID_NIK = '3171010101900001';
const INVALID_NIK = '9911010101900001'; // unknown province, still 16 digits

test('NIK verdict is derived server-side; client verdict is ignored', async () => {
  const em = U('nik');
  const token = await userToken(em);
  const res = await request(app)
    .post('/identity/nik/validate')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, nik: INVALID_NIK, verdict: 'VALID', nikHash: 'spoof', nikLast4: 'spoof' });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data, ['NIK_RECORDED']);
  const status = queryScalar(
    `SELECT status FROM identity_verifications WHERE user_id=(SELECT id FROM users WHERE email='${em}') ORDER BY id DESC LIMIT 1;`,
  );
  assert.equal(status, 'INVALID');
  const hash = queryScalar(`SELECT nik_hash FROM users WHERE email='${em}';`);
  assert.match(hash, /^[0-9a-f]{64}$/);
  assert.notEqual(hash, 'spoof');
  assert.equal(queryScalar(`SELECT kyc_status FROM users WHERE email='${em}';`), 'UNVERIFIED');
});

test('structurally valid NIK records VALID without client help', async () => {
  const em = U('nikok');
  const token = await userToken(em);
  const res = await request(app)
    .post('/identity/nik/validate')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, nik: VALID_NIK });
  assert.equal(res.status, 200);
  assert.equal(queryScalar(`SELECT kyc_status FROM users WHERE email='${em}';`), 'NIK_VALID');
  assert.equal(queryScalar(`SELECT nik_last4 FROM users WHERE email='${em}';`), '0001');
});

test('screening requires consent and records the adapter verdict', async () => {
  const em = U('scr');
  const token = await userToken(em);
  const res = await request(app)
    .post('/screening/check')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, name: 'John Doe', consent: '1' });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data, ['SCREEN_RECORDED']);
  const verdict = queryScalar(
    `SELECT result FROM screening_checks WHERE user_id=(SELECT id FROM users WHERE email='${em}') ORDER BY id DESC LIMIT 1;`,
  );
  assert.equal(verdict, 'CLEAR');
  const qhash = queryScalar(
    `SELECT query_hash FROM screening_checks WHERE user_id=(SELECT id FROM users WHERE email='${em}') ORDER BY id DESC LIMIT 1;`,
  );
  assert.match(qhash, /^[0-9a-f]{64}$/);
});

test('screening without consent is rejected; spoofed CLEAR without a name is rejected', async () => {
  const em = U('scrnc');
  const token = await userToken(em);
  const noConsent = await request(app)
    .post('/screening/check')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, name: 'John Doe' });
  assert.equal(noConsent.status, 400);
  const spoof = await request(app)
    .post('/screening/check')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, result: 'CLEAR', queryHash: 'f'.repeat(64) });
  assert.equal(spoof.status, 400);
});

test('risk note is derived from the socket IP; client signals are ignored', async () => {
  const em = U('risk');
  const token = await userToken(em);
  const res = await request(app)
    .post('/risk/note')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, country: 'XX', ipHashFlags: 'spoof' });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data, ['RISK_NOTED']);
  const row = queryScalar(
    `SELECT CONCAT(country,'|',ip_hash) FROM risk_events WHERE user_id=(SELECT id FROM users WHERE email='${em}') ORDER BY id DESC LIMIT 1;`,
  );
  const [country, hash] = row.split('|');
  assert.equal(country, 'UNKNOWN'); // loopback short-circuits server-side
  assert.match(hash, /^[0-9a-f]{64}$/);
  assert.ok(!row.includes('127.0.0.1'));
});

test('OTP issue requires purpose and never returns the code', async () => {
  const em = U('otp');
  const token = await userToken(em);
  const res = await request(app)
    .post('/auth/phone/otp/issue')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, channel: 'EMAIL', purpose: 'TB_PURPOSE' });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data, ['OTP_SENT']);
  assert.equal(res.body.code, undefined);
  assert.ok(!JSON.stringify(res.body).includes('OTP_ISSUED'));
  assert.equal(res.body.delivered, true);
  const missing = await request(app)
    .post('/auth/phone/otp/issue')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, channel: 'EMAIL' });
  assert.equal(missing.status, 400);
});

test('OTP issue over PHONE reports undelivered without a linked chat, still no code', async () => {
  const em = U('otpph');
  const token = await userToken(em);
  const res = await request(app)
    .post('/auth/phone/otp/issue')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, channel: 'PHONE', purpose: 'TB_PHONE' });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data, ['OTP_SENT']);
  assert.equal(res.body.delivered, false);
});

test('phone link hashes the number server-side; client hash is ignored', async () => {
  const em = U('phl');
  const token = await userToken(em);
  const res = await request(app)
    .post('/auth/phone/link/begin')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, phone: '+6281234567890', phoneHash: 'spoof' });
  assert.equal(res.status, 200);
  // The link token is returned by design (single-use ceremony token the
  // client presents back with its chat id); the phone hash is derived.
  assert.equal(res.body.data[0], 'LINK_BEGIN');
  const stored = queryScalar(
    `SELECT phone_hash FROM phone_links WHERE user_id=(SELECT id FROM users WHERE email='${em}');`,
  );
  assert.match(stored, /^[0-9a-f]{64}$/);
  assert.notEqual(stored, 'spoof');
});

test('free_sms sends only to the verified number; mismatch never sends', async () => {
  const { resetProviders } = await import('../services/integrations/index.js');
  const em = U('sms');
  const token = await userToken(em);
  const begun = await request(app)
    .post('/auth/phone/link/begin')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, phone: '+6281234567890' });
  const linkToken = begun.body.data[1];
  const confirmed = await request(app)
    .post('/auth/phone/link/confirm')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, token: linkToken, chatId: 'chat-sms-1' });
  assert.equal(confirmed.status, 200);
  const saved = {
    PHONE_OTP_PROVIDER: process.env.PHONE_OTP_PROVIDER,
    FREE_SMS_ENDPOINT: process.env.FREE_SMS_ENDPOINT,
    FREE_SMS_API_KEY: process.env.FREE_SMS_API_KEY,
  };
  try {
    process.env.PHONE_OTP_PROVIDER = 'free_sms';
    process.env.FREE_SMS_ENDPOINT = 'http://127.0.0.1:1/unreachable';
    process.env.FREE_SMS_API_KEY = 'test-key';
    resetProviders();
    // Matching number reaches the relay (refused here) without leaking code.
    const match = await request(app)
      .post('/auth/phone/otp/issue')
      .set('Authorization', `Bearer ${token}`)
      .send({ email: em, channel: 'PHONE', purpose: 'TB_SMS', phone: '+6281234567890' });
    assert.equal(match.status, 200);
    assert.deepEqual(match.body.data, ['OTP_SENT']);
    assert.equal(match.body.delivered, false);
    // A different number never reaches the relay (verified-hash mismatch).
    const mismatch = await request(app)
      .post('/auth/phone/otp/issue')
      .set('Authorization', `Bearer ${token}`)
      .send({ email: em, channel: 'PHONE', purpose: 'TB_SMS2', phone: '+6289999999999' });
    assert.equal(mismatch.status, 200);
    assert.equal(mismatch.body.delivered, false);
  } finally {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
    resetProviders();
  }
});

test('PHONE issue delivers via the linked chat without exposing the code', async () => {
  const { resetProviders } = await import('../services/integrations/index.js');
  const em = U('tgchat');
  const token = await userToken(em);
  resetProviders();
  const begun = await request(app)
    .post('/auth/phone/link/begin')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, phone: '+6281234567890' });
  const linkToken = begun.body.data[1];
  const confirmed = await request(app)
    .post('/auth/phone/link/confirm')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, token: linkToken, chatId: 'chat-tg-1' });
  assert.equal(confirmed.status, 200);
  const res = await request(app)
    .post('/auth/phone/otp/issue')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, channel: 'PHONE', purpose: 'TB_TG' });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.data, ['OTP_SENT']);
  assert.equal(res.body.code, undefined);
});

test('free_sms without a verified number never sends', async () => {
  const { resetProviders } = await import('../services/integrations/index.js');
  const { resetBreakers } = await import('../services/integrations/resilience.js');
  const { resetQuota } = await import('../services/integrations/quota.js');
  const em = U('smsnonum');
  const token = await userToken(em);
  // Link and confirm first so the account has a verified stored hash; the
  // issue below then omits the number, hitting the no_verified_number path.
  const begun = await request(app)
    .post('/auth/phone/link/begin')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, phone: '+6281234567890' });
  const linkToken = begun.body.data[1];
  const confirmed = await request(app)
    .post('/auth/phone/link/confirm')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, token: linkToken, chatId: 'chat-sms-nonum' });
  assert.equal(confirmed.status, 200);
  const saved = {
    PHONE_OTP_PROVIDER: process.env.PHONE_OTP_PROVIDER,
    FREE_SMS_ENDPOINT: process.env.FREE_SMS_ENDPOINT,
    FREE_SMS_API_KEY: process.env.FREE_SMS_API_KEY,
  };
  try {
    process.env.PHONE_OTP_PROVIDER = 'free_sms';
    process.env.FREE_SMS_ENDPOINT = 'http://127.0.0.1:1/unreachable';
    process.env.FREE_SMS_API_KEY = 'test-key';
    resetProviders();
    resetBreakers();
    resetQuota();
    // Verified hash exists server-side but no number supplied: the relay
    // must not be touched, delivery reports false, no code leaks.
    const res = await request(app)
      .post('/auth/phone/otp/issue')
      .set('Authorization', `Bearer ${token}`)
      .send({ email: em, channel: 'PHONE', purpose: 'TB_SMS_NONUM' });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body.data, ['OTP_SENT']);
    assert.equal(res.body.delivered, false);
    assert.equal(res.body.code, undefined);
  } finally {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
    resetProviders();
    resetBreakers();
    resetQuota();
  }
});

test('free_sms to the verified number delivers with no code in the response', async () => {
  const { resetProviders } = await import('../services/integrations/index.js');
  const { resetBreakers } = await import('../services/integrations/resilience.js');
  const { resetQuota } = await import('../services/integrations/quota.js');
  const em = U('smsok');
  const token = await userToken(em);
  const begun = await request(app)
    .post('/auth/phone/link/begin')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, phone: '+6281234567890' });
  const linkToken = begun.body.data[1];
  const confirmed = await request(app)
    .post('/auth/phone/link/confirm')
    .set('Authorization', `Bearer ${token}`)
    .send({ email: em, token: linkToken, chatId: 'chat-sms-ok' });
  assert.equal(confirmed.status, 200);
  // Local relay that accepts every send: proves the match path delivers.
  const seen = [];
  const relay = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => {
      body += c;
    });
    req.on('end', () => {
      seen.push(body);
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end('{"ok":true}');
    });
  });
  await new Promise((resolve) => relay.listen(0, '127.0.0.1', resolve));
  const port = relay.address().port;
  const saved = {
    PHONE_OTP_PROVIDER: process.env.PHONE_OTP_PROVIDER,
    FREE_SMS_ENDPOINT: process.env.FREE_SMS_ENDPOINT,
    FREE_SMS_API_KEY: process.env.FREE_SMS_API_KEY,
  };
  try {
    process.env.PHONE_OTP_PROVIDER = 'free_sms';
    process.env.FREE_SMS_ENDPOINT = `http://127.0.0.1:${port}/send`;
    process.env.FREE_SMS_API_KEY = 'test-key';
    resetProviders();
    resetBreakers();
    resetQuota();
    const res = await request(app)
      .post('/auth/phone/otp/issue')
      .set('Authorization', `Bearer ${token}`)
      .send({ email: em, channel: 'PHONE', purpose: 'TB_SMS_OK', phone: '+6281234567890' });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body.data, ['OTP_SENT']);
    assert.equal(res.body.delivered, true);
    assert.equal(res.body.code, undefined);
    assert.equal(seen.length, 1);
    assert.ok(seen[0].includes('+6281234567890'));
  } finally {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
    resetProviders();
    resetBreakers();
    resetQuota();
    await new Promise((resolve) => relay.close(resolve));
  }
});
