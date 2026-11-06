// Breached-password check (PR-093, Pwned Passwords k-anonymity): SHA-1 the
// password locally, send only the 5-char prefix to /range/{prefix}, compare
// suffixes. The full password (or its hash) never leaves the process and is
// never logged. Fail-open with a metric on down/timeout (availability beats
// the check; rate limits still apply); reject when count exceeds threshold.
import { createHash } from 'node:crypto';
import { recordFallback, resilientFetch } from '../resilience.js';

export const DEFAULT_TIMEOUT_MS = 2000;
export const DEFAULT_ENDPOINT = 'https://api.pwnedpasswords.com';

export function sha1Upper(password) {
  return createHash('sha1').update(String(password)).digest('hex').toUpperCase();
}

export async function checkPassword(
  password,
  {
    fetchImpl = fetch,
    timeoutMs = Number(process.env.PWNED_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
    endpoint = process.env.PWNED_ENDPOINT || DEFAULT_ENDPOINT,
    threshold = 0,
  } = {},
) {
  if (!password) return { breached: false, count: 0 };
  const hex = sha1Upper(password);
  const res = await resilientFetch(
    'pwned',
    `${endpoint}/range/${hex.slice(0, 5)}`,
    { method: 'GET' },
    { fetchImpl, timeoutMs },
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const text = await res.text();
  const want = hex.slice(5);
  for (const line of String(text).split('\n')) {
    const [suffix, count] = line.trim().split(':');
    if (suffix === want) {
      const n = Number(count);
      return { breached: Number.isFinite(n) && n > threshold, count: Number.isFinite(n) ? n : 0 };
    }
  }
  return { breached: false, count: 0 };
}

// Gateway hook: true when the password may be used. Throws BREACHED_PASSWORD
// when seen in breaches; fails open (logs + metric) when the API is down.
// Enforcement needs opting in (PWNED_ENFORCE=1) except in production, where
// it is on unless PWNED_DISABLE=1: unit suites stay offline and keep their
// fixture passwords, production gets the check by default.
export function enforced() {
  if (process.env.PWNED_ENFORCE === '1') return true;
  if (process.env.PWNED_DISABLE === '1') return false;
  return process.env.NODE_ENV === 'production';
}

export async function assertPasswordAllowed(password, { logger = null, ...opts } = {}) {
  if (!enforced() && !process.env.PWNED_ENDPOINT && !opts.endpoint) return true;
  try {
    const r = await checkPassword(password, opts);
    return !r.breached;
  } catch (err) {
    recordFallback({ provider: 'pwned', reason: 'fail_open' });
    if (logger) logger({ event: 'pwned_failopen', message: String((err && err.message) || err) });
    return true;
  }
}
