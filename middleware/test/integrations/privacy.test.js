import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  redactChatId,
  redactCode,
  redactNik,
  redactPhone,
  redactToken,
  scanForPii,
  scrubEvent,
  scrubText,
} from '../../services/integrations/redact.js';

const NIK = '3171010101900001';
const PHONE = '+628123456789';
const CODE = '895163';

// --- scrubber units ---------------------------------------------------------

test('redactNik keeps last4 only, no 16-digit run survives', () => {
  const r = redactNik(NIK);
  assert.ok(!r.includes(NIK));
  assert.ok(!/\d{16}/.test(r));
  assert.ok(r.endsWith('0001'));
});

test('redactPhone keeps last4 only, raw number absent', () => {
  const r = redactPhone(PHONE);
  assert.ok(!r.includes('628123456789'));
  assert.ok(r.endsWith('6789'));
  assert.equal(redactPhone('abc'), '[redacted]');
});

test('codes and tokens are fully dropped, never partial', () => {
  assert.equal(redactCode(CODE), '[redacted]');
  assert.equal(redactToken('secret'), '[redacted]');
  assert.equal(redactChatId('chat-777'), '…-777');
});

test('scrubEvent scrubs PII keys but preserves email recipients and safe keys', () => {
  const out = scrubEvent({
    event: 'phone_otp',
    to: 'a@test.com',
    nik: NIK,
    phone: PHONE,
    code: CODE,
    chatId: 'chat-777',
    channel: 'telegram',
  });
  assert.equal(out.to, 'a@test.com');
  assert.equal(out.channel, 'telegram');
  assert.deepEqual(scanForPii(out), []);
});

test('scrubEvent redacts a phone-looking recipient', () => {
  const out = scrubEvent({ event: 'phone_otp', to: PHONE });
  assert.deepEqual(scanForPii(out), []);
  assert.ok(!JSON.stringify(out).includes('628123456789'));
});

test('scrubText masks NIK runs and leaves short numbers alone', () => {
  assert.ok(!/\d{16}/.test(scrubText(`nik ${NIK} here`)));
  assert.ok(scrubText('port 1025 count 42').includes('1025'));
});

test('scanForPii flags raw PII and passes clean events', () => {
  assert.deepEqual(scanForPii({ event: 'x', channel: 'sms' }), []);
  assert.ok(scanForPii({ event: 'x', nik: NIK }).length > 0);
  assert.ok(scanForPii({ event: 'x', code: CODE }).length > 0);
  assert.ok(scanForPii(`quote ${NIK}`).length > 0);
});

// --- provider log scan (PR-087 acceptance) ----------------------------------

test('no provider log line carries NIK, phone, code, or token', async () => {
  const lines = [];
  const logger = (e) => lines.push(e);
  const { createPhoneProvider } = await import('../../services/integrations/phone.js');
  const { createEmailProvider } = await import('../../services/integrations/email.js');
  const { createIdentityProvider } = await import('../../services/integrations/identity.js');

  const mock = createPhoneProvider('mock', { logger });
  await mock.sendOtp({ to: PHONE, channel: 'sms', code: CODE });

  process.env.TELEGRAM_BOT_TOKEN = 'test-token';
  const okFetch = () => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ ok: true }) });
  try {
    const tg = createPhoneProvider('telegram', { logger });
    await tg.sendOtp({ chatId: 'chat-999', code: CODE, fetchImpl: okFetch });
    const { sendTelegramOtp } = await import('../../services/integrations/phone/telegram.js');
    await sendTelegramOtp({ chatId: 'chat-999', text: `Your verification code is ${CODE}` }, { fetchImpl: okFetch });
  } finally {
    delete process.env.TELEGRAM_BOT_TOKEN;
  }

  const email = createEmailProvider('log', { logger });
  await email.sendVerification({ to: 'a@test.com', purpose: 'SIGNUP', code: CODE });
  await email.sendNotice({ to: 'a@test.com', subject: 'Hi', text: 'x' });

  const identity = createIdentityProvider('mock', { logger });
  await identity.validateNik({ nik: NIK });

  process.env.NUSAKIT_ENDPOINT = 'https://allow.example/nik';
  process.env.NUSAKIT_ALLOWLIST = 'allow.example';
  try {
    const { validateNikRemote } = await import('../../services/integrations/identity/nusakit.js');
    await validateNikRemote(
      { nik: NIK, consent: true },
      { fetchImpl: () => Promise.resolve({ ok: true, json: () => Promise.resolve({ verdict: 'match' }) }) },
    );
  } finally {
    delete process.env.NUSAKIT_ENDPOINT;
    delete process.env.NUSAKIT_ALLOWLIST;
  }

  assert.ok(lines.length >= 4, `expected provider log lines, got ${lines.length}`);
  for (const line of lines) {
    assert.deepEqual(scanForPii(line), [], `PII leak in ${JSON.stringify(line)}`);
  }
  const blob = JSON.stringify(lines);
  assert.ok(!blob.includes(NIK), 'raw NIK in logs');
  assert.ok(!blob.includes('628123456789'), 'raw phone in logs');
  assert.ok(!blob.includes(CODE), 'raw OTP code in logs');
});
