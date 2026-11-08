// Production secret requirements (PR-089): .env files are development-only.
// In production every secret a configured provider needs must be present in
// the environment (injected by the secret manager: SOPS/age, Infisical, or
// Vault — see docs/INTEGRATION_HARDENING.md); boot fails otherwise. Secrets
// are never logged (use maskedSecrets() for diagnostics).
const SECRET_FOR = {
  email: { smtp: ['SMTP_HOST'], mailpit: [] },
  phone: { telegram: ['TELEGRAM_BOT_TOKEN'], free_sms: ['FREE_SMS_ENDPOINT', 'FREE_SMS_API_KEY'] },
  identity: { nusakit: ['NUSAKIT_ENDPOINT'] },
};

// Names that must never appear in cleartext logs.
const SECRET_NAMES = [
  'SMTP_PASS',
  'TELEGRAM_BOT_TOKEN',
  'FREE_SMS_API_KEY',
  'NIK_HMAC_SECRET',
];

export function requiredSecrets(config) {
  const out = [];
  if (config.email === 'smtp' && process.env.SMTP_USER) out.push('SMTP_PASS');
  for (const [channel, providers] of Object.entries(SECRET_FOR)) {
    const kind = config[channel];
    // Remote identity is consent-gated per call, not a boot provider; its
    // endpoint is required only when a call actually uses it.
    if (channel === 'identity') continue;
    for (const name of providers[kind] || []) out.push(name);
  }
  return [...new Set(out)];
}

export function missingSecrets(config) {
  return requiredSecrets(config).filter((name) => !process.env[name]);
}

// Fail fast at boot (production only): an empty required secret means the
// secret manager did not inject it. Development/test always pass.
export function assertSecrets(config = null) {
  if (process.env.NODE_ENV !== 'production') return config;
  const cfg = config || {};
  const missing = missingSecrets(cfg);
  if (missing.length) {
    throw new Error(`production secrets missing (check the secret manager): ${missing.join(', ')}`);
  }
  return cfg;
}

// Diagnostics-safe view: every secret value replaced, names kept.
export function maskedSecrets(env = process.env) {
  const out = {};
  for (const name of SECRET_NAMES) {
    if (env[name]) out[name] = '[set]';
  }
  return out;
}
