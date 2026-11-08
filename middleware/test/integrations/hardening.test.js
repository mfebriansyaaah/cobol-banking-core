import { test } from 'node:test';
import assert from 'node:assert/strict';
import { assertSecrets, maskedSecrets, missingSecrets, requiredSecrets } from '../../services/integrations/secrets.js';
import { assertQuota, quotaLimit, quotaStatus, recordUse, resetQuota } from '../../services/integrations/quota.js';

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
  }
}

test('required secrets follow the configured providers', () => {
  assert.deepEqual(requiredSecrets({ email: 'log', phone: 'mock' }), []);
  assert.deepEqual(requiredSecrets({ email: 'log', phone: 'telegram' }), ['TELEGRAM_BOT_TOKEN']);
  assert.deepEqual(
    requiredSecrets({ email: 'smtp', phone: 'free_sms', identity: 'local' }).sort(),
    ['FREE_SMS_API_KEY', 'FREE_SMS_ENDPOINT', 'SMTP_HOST'].sort(),
  );
});

test('missing secrets fail boot in production only', () => {
  withEnv({ NODE_ENV: 'production', TELEGRAM_BOT_TOKEN: undefined }, () => {
    assert.deepEqual(missingSecrets({ email: 'log', phone: 'telegram' }), ['TELEGRAM_BOT_TOKEN']);
    assert.throws(() => assertSecrets({ email: 'log', phone: 'telegram' }), /TELEGRAM_BOT_TOKEN/);
  });
  withEnv({ NODE_ENV: 'test', TELEGRAM_BOT_TOKEN: undefined }, () => {
    assert.doesNotThrow(() => assertSecrets({ email: 'log', phone: 'telegram' }));
  });
  withEnv({ NODE_ENV: 'production', TELEGRAM_BOT_TOKEN: 'x' }, () => {
    assert.doesNotThrow(() => assertSecrets({ email: 'log', phone: 'telegram' }));
  });
});

test('maskedSecrets never carries values', () => {
  const m = withEnv({ TELEGRAM_BOT_TOKEN: 'shh', SMTP_PASS: 'shh' }, () => maskedSecrets());
  assert.deepEqual(m, { SMTP_PASS: '[set]', TELEGRAM_BOT_TOKEN: '[set]' });
  assert.ok(!JSON.stringify(m).includes('shh'));
});

test('quota allows under budget and alerts once at 80%', () => {
  resetQuota();
  withEnv({ QUOTA_TELEGRAM_DAILY: '10' }, () => {
    assert.equal(quotaLimit('telegram'), 10);
    const seen = [];
    for (let i = 0; i < 7; i += 1) recordUse('telegram');
    assertQuota('telegram', { logger: (e) => seen.push(e) });
    assert.equal(seen.length, 0);
    recordUse('telegram');
    assertQuota('telegram', { logger: (e) => seen.push(e) });
    assert.equal(seen.length, 1);
    assert.equal(seen[0].event, 'integration_quota_alert');
    assertQuota('telegram', { logger: (e) => seen.push(e) });
    assert.equal(seen.length, 1, 'alert fires once');
    assert.deepEqual(quotaStatus('telegram'), {
      provider: 'telegram',
      used: 8,
      limit: 10,
      disabled: false,
      alert: true,
    });
  });
  resetQuota();
});

test('quota kill switch (limit 0) and budget exhaustion throw', () => {
  resetQuota();
  withEnv({ QUOTA_FREE_SMS_DAILY: '0' }, () => {
    assert.throws(() => assertQuota('free_sms'), /kill switch/);
  });
  withEnv({ QUOTA_NUSAKIT_DAILY: '1' }, () => {
    recordUse('nusakit');
    assert.throws(() => assertQuota('nusakit'), /QUOTA_EXCEEDED/);
  });
  resetQuota();
});

test('quota defaults are finite fallbacks per provider', () => {
  withEnv({ QUOTA_TELEGRAM_DAILY: undefined }, () => {
    assert.ok(quotaLimit('telegram') > 0);
    assert.equal(quotaLimit('telegram'), 1000);
  });
});
