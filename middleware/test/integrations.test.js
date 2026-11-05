import { test } from 'node:test';
import assert from 'node:assert/strict';
import { integrationConfig, assertIntegrationConfig } from '../src/integrations/config.js';
import {
  EMAIL_PROVIDER,
  PHONE_PROVIDER,
  IDENTITY_PROVIDER,
  OCR_PROVIDER,
  getProviders,
  resetProviders,
} from '../src/integrations/index.js';
import { validateNikStructure } from '../src/integrations/identity.js';

function withEnv(vars, fn) {
  const saved = {};
  for (const k of Object.keys(vars)) {
    saved[k] = process.env[k];
    if (vars[k] === undefined) delete process.env[k];
    else process.env[k] = vars[k];
  }
  try {
    return fn();
  } finally {
    for (const k of Object.keys(vars)) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
    resetProviders();
  }
}

test('defaults are all-local with zero dependencies', () => {
  withEnv({ INTEGRATION_MODE: undefined, EMAIL_PROVIDER: undefined, PHONE_OTP_PROVIDER: undefined }, () => {
    assert.deepEqual(integrationConfig(), {
      mode: 'local',
      email: 'log',
      phone: 'mock',
      identity: 'mock',
      ocr: 'mock',
    });
  });
});

test('unknown provider fails fast', () => {
  withEnv({ EMAIL_PROVIDER: 'pigeon' }, () => {
    assert.throws(() => integrationConfig(), /invalid EMAIL_PROVIDER/);
  });
});

test('production smtp without host fails fast', () => {
  withEnv({ NODE_ENV: 'production', EMAIL_PROVIDER: 'smtp', SMTP_HOST: undefined }, () => {
    assert.throws(() => assertIntegrationConfig(), /SMTP_HOST/);
  });
});

test('production telegram without token fails fast', () => {
  withEnv({ NODE_ENV: 'production', PHONE_OTP_PROVIDER: 'telegram', TELEGRAM_BOT_TOKEN: undefined }, () => {
    assert.throws(() => assertIntegrationConfig(), /TELEGRAM_BOT_TOKEN/);
  });
});

test('every provider implements its frozen interface', () => {
  withEnv({}, () => {
    const p = getProviders();
    for (const [impl, iface] of [
      [p.email, EMAIL_PROVIDER],
      [p.phone, PHONE_PROVIDER],
      [p.identity, IDENTITY_PROVIDER],
      [p.ocr, OCR_PROVIDER],
    ]) {
      for (const m of iface) assert.equal(typeof impl[m], 'function', m);
    }
  });
});

test('mock phone records without network', async () => {
  await withEnv({}, async () => {
    const p = getProviders();
    assert.equal(await p.phone.sendOtp({ to: '+62000', channel: 'sms' }), true);
    assert.equal((await p.identity.validateNik({ nik: 'x' })).ok, true);
    const h = await p.phone.health();
    assert.equal(h.ok, true);
  });
});

test('local NIK validation is structural only', () => {
  assert.deepEqual(validateNikStructure('1234560101900001'), { ok: true, reason: null });
  assert.equal(validateNikStructure('123').ok, false);
  assert.equal(validateNikStructure('1234569901900001').ok, false);
  assert.equal(validateNikStructure('abcdefghijklmnop').ok, false);
});

test('unimplemented providers fail closed, not silent', async () => {
  await withEnv({ PHONE_OTP_PROVIDER: 'telegram' }, async () => {
    const p = getProviders();
    await assert.rejects(() => p.phone.sendOtp({ to: '+62000' }), /not implemented yet/);
    const h = await p.phone.health();
    assert.equal(h.ok, false);
  });
});
