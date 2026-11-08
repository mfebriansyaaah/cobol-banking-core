// Free-tier quota guard (PR-089): process-local daily counters per provider
// so a runaway loop cannot silently burn the free tier. Limits come from env
// (QUOTA_<PROVIDER>_DAILY, 0 = kill switch: provider hard-disabled, callers
// fall back to local/manual). At 80% an alert line is logged once per day.
// Counters reset on restart and at UTC midnight; this is a tripwire, not
// billing — see docs/INTEGRATION_HARDENING.md.
const DEFAULT_LIMITS = {
  telegram: 1000,
  free_sms: 100,
  nusakit: 500,
  smtp: 1000,
  mailpit: 100000,
};

const usage = new Map(); // provider -> { count, day, alerted }

export function resetQuota() {
  usage.clear();
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

export function quotaLimit(provider) {
  const raw = process.env[`QUOTA_${provider.toUpperCase()}_DAILY`];
  if (raw !== undefined && raw !== '') {
    const n = Number(raw);
    if (Number.isFinite(n) && n >= 0) return Math.floor(n);
  }
  return DEFAULT_LIMITS[provider] ?? 100;
}

function entry(provider) {
  const day = today();
  let e = usage.get(provider);
  if (!e || e.day !== day) {
    e = { count: 0, day, alerted: false };
    usage.set(provider, e);
  }
  return e;
}

export function quotaStatus(provider) {
  const e = entry(provider);
  const limit = quotaLimit(provider);
  return {
    provider,
    used: e.count,
    limit,
    disabled: limit === 0,
    alert: limit > 0 && e.count >= Math.floor(limit * 0.8),
  };
}

// Throw QUOTA_EXCEEDED (callers fall back) when the provider is disabled or
// over budget. Logs the 80% alert once per provider per day.
export function assertQuota(provider, { logger = null } = {}) {
  const st = quotaStatus(provider);
  if (st.disabled) {
    throw new Error(`QUOTA_EXCEEDED: provider '${provider}' disabled by kill switch`);
  }
  if (st.used >= st.limit) {
    throw new Error(`QUOTA_EXCEEDED: provider '${provider}' over daily budget (${st.used}/${st.limit})`);
  }
  const e = entry(provider);
  if (!e.alerted && st.alert) {
    e.alerted = true;
    if (logger) logger({ event: 'integration_quota_alert', provider, used: st.used, limit: st.limit });
  }
  return st;
}

export function recordUse(provider) {
  entry(provider).count += 1;
  return quotaStatus(provider);
}
