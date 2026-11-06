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

async function withEnv(vars, fn) {
  const saved = {};
  for (const k of Object.keys(vars)) {
    saved[k] = process.env[k];
    if (vars[k] === undefined) delete process.env[k];
    else process.env[k] = vars[k];
  }
  try {
    return await fn();
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

test('email log provider sends and reports healthy', async () => {
  await withEnv({ EMAIL_PROVIDER: 'log' }, async () => {
    const p = getProviders();
    const seen = [];
    const { createEmailProvider } = await import('../src/integrations/email.js');
    const prov = createEmailProvider('log', { logger: (e) => seen.push(e) });
    assert.equal(await prov.sendVerification({ to: 'a@t.co', purpose: 'X' }), true);
    assert.equal(await prov.sendNotice({ to: 'a@t.co', subject: 'Hi' }), true);
    assert.equal(seen.length, 2);
    assert.deepEqual(await prov.health(), { ok: true, provider: 'log', detail: null });
    assert.equal(p.email.kind, 'log');
  });
});

test('email smtp factory builds without network', async () => {
  await withEnv({ EMAIL_PROVIDER: 'smtp', SMTP_HOST: undefined }, async () => {
    const { createEmailProvider } = await import('../src/integrations/email.js');
    const prov = createEmailProvider('smtp');
    assert.equal(prov.kind, 'smtp');
    const h = await prov.health();
    assert.equal(h.provider, 'smtp');
    // No SMTP configured: best-effort delivery reports false, no network.
    assert.equal(await prov.sendVerification({ to: 'a@t.co', purpose: 'X', code: '1' }), false);
    assert.equal(await prov.sendNotice({ to: 'a@t.co', subject: 's', text: 't' }), false);
  });
  await withEnv({ MAILPIT_HOST: 'mp', SMTP_HOST: undefined }, async () => {
    const { createEmailProvider } = await import('../src/integrations/email.js');
    const prov = createEmailProvider('mailpit');
    const h = await prov.health();
    assert.equal(h.ok, true);
    assert.equal(h.detail.host, 'mp');
  });
});

test('identity local provider validates structurally', async () => {
  await withEnv({ IDENTITY_PROVIDER: 'local' }, async () => {
    const p = getProviders();
    assert.equal(p.identity.kind, 'local');
    assert.deepEqual(await p.identity.validateNik({ nik: '1234560101900001' }), {
      ok: true,
      reason: null,
    });
    assert.equal((await p.identity.validateNik({ nik: 'nope' })).ok, false);
    assert.equal((await p.identity.health()).ok, true);
    const { createIdentityProvider } = await import('../src/integrations/identity.js');
    const mock = createIdentityProvider('mock');
    assert.equal((await mock.health()).ok, true);
  });
});

test('ocr mock extracts, local fails closed', async () => {
  await withEnv({}, async () => {
    const p = getProviders();
    const r = await p.ocr.extractKtp({ imageRef: 'img-1' });
    assert.equal(r.ok, true);
    assert.equal(r.needsReview, false);
    assert.equal((await p.ocr.health()).ok, true);
    const { createOcrProvider, OCR_REVIEW_THRESHOLD } = await import('../src/integrations/ocr.js');
    assert.equal(OCR_REVIEW_THRESHOLD, 0.85);
    const local = createOcrProvider('local');
    await assert.rejects(() => local.extractKtp({ imageRef: 'x' }), /not implemented yet/);
    assert.equal((await local.health()).ok, false);
  });
});

test('production config gaps fail fast with names', async () => {
  await withEnv(
    {
      NODE_ENV: 'production',
      EMAIL_PROVIDER: 'smtp',
      SMTP_HOST: 'h',
      SMTP_USER: 'u',
      SMTP_PASS: undefined,
      PHONE_OTP_PROVIDER: 'mock',
    },
    () => {
      assert.throws(() => assertIntegrationConfig(), /SMTP_PASS/);
    },
  );
  await withEnv({ NODE_ENV: 'production', EMAIL_PROVIDER: 'mailpit', SMTP_HOST: undefined }, () => {
    assert.throws(() => assertIntegrationConfig(), /MAILPIT_HOST/);
  });
  await withEnv(
    {
      NODE_ENV: 'production',
      EMAIL_PROVIDER: 'smtp',
      SMTP_HOST: 'h',
      PHONE_OTP_PROVIDER: 'mock',
    },
    () => {
      assert.ok(assertIntegrationConfig().email === 'smtp');
    },
  );
});
