// Integration provider configuration (PR-080): one env-driven switchboard
// for every external provider, so later slices (081+) add channels without
// touching call sites. Unknown providers and production-without-secrets
// fail fast at boot via assertIntegrationConfig(); development boots with
// zero external dependencies (all-local defaults).
const MODES = ['local', 'free', 'sandbox', 'production'];
const EMAIL_PROVIDERS = ['log', 'mailpit', 'smtp'];
const PHONE_PROVIDERS = ['mock', 'telegram', 'free_sms'];
const IDENTITY_PROVIDERS = ['mock', 'local'];
const OCR_PROVIDERS = ['mock', 'local'];

function pick(name, allowed, fallback) {
  const raw = (process.env[name] || '').trim().toLowerCase();
  const value = raw === '' ? fallback : raw;
  if (!allowed.includes(value)) {
    throw new Error(`invalid ${name}=${JSON.stringify(raw || value)} (allowed: ${allowed.join(', ')})`);
  }
  return value;
}

export function integrationConfig() {
  const mode = pick('INTEGRATION_MODE', MODES, 'local');
  return {
    mode,
    email: pick('EMAIL_PROVIDER', EMAIL_PROVIDERS, 'log'),
    phone: pick('PHONE_OTP_PROVIDER', PHONE_PROVIDERS, 'mock'),
    identity: pick('IDENTITY_PROVIDER', IDENTITY_PROVIDERS, 'mock'),
    ocr: pick('KTP_OCR_PROVIDER', OCR_PROVIDERS, 'mock'),
  };
}

// Fail-fast validation for server boot. Pure (reads env only): unknown
// providers throw; production without the secrets its providers need throws.
// Development/test with defaults always passes.
export function assertIntegrationConfig() {
  const cfg = integrationConfig();
  const missing = [];
  if (process.env.NODE_ENV === 'production') {
    if (cfg.email === 'smtp' && !process.env.SMTP_HOST) missing.push('SMTP_HOST');
    if (cfg.email === 'smtp' && process.env.SMTP_USER && !process.env.SMTP_PASS) {
      missing.push('SMTP_PASS');
    }
    if (cfg.email === 'mailpit' && !process.env.SMTP_HOST && !process.env.MAILPIT_HOST) {
      missing.push('SMTP_HOST (or MAILPIT_HOST for the mailpit provider)');
    }
    if (cfg.phone === 'telegram' && !process.env.TELEGRAM_BOT_TOKEN) {
      missing.push('TELEGRAM_BOT_TOKEN');
    }
  }
  if (missing.length) {
    throw new Error(`production integration misconfigured, missing: ${missing.join(', ')}`);
  }
  return cfg;
}
