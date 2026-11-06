// Bot protection (PR-094, Cloudflare Turnstile): server-side token verify.
// The token is single-use, never stored, never logged. Fail-open with a
// metric on provider down (availability first; the auth rate limiters still
// apply and tighten the window). Enforced only when TURNSTILE_SECRET is set;
// unset means the check is skipped (dev/test default, documented).
import { recordFallback, resilientFetch, DEFAULT_TIMEOUT_MS } from '../resilience.js';

export const VERIFY_URL = 'https://challenges.cloudflare.com/turnstile/v0/siteverify';

const ERROR_TTL = new Map(); // error-code -> count (telemetry only)

export function turnstileEnabled() {
  return Boolean(process.env.TURNSTILE_SECRET);
}

export async function verifyTurnstile(
  token,
  {
    fetchImpl = fetch,
    timeoutMs = Number(process.env.TURNSTILE_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
    endpoint = process.env.TURNSTILE_VERIFY_URL || VERIFY_URL,
    secret = process.env.TURNSTILE_SECRET,
    remoteip = null,
    logger = null,
  } = {},
) {
  if (!token) return { ok: false, code: 'missing-input-response' };
  if (!secret) return { ok: true, skipped: true };
  try {
    const body = new URLSearchParams({ secret, response: token });
    if (remoteip) body.set('remoteip', remoteip);
    const res = await resilientFetch(
      'turnstile',
      endpoint,
      { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: body.toString() },
      { fetchImpl, timeoutMs, idempotencyKey: null },
    );
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    let data;
    try {
      data = await res.json();
    } catch {
      throw new Error('malformed JSON');
    }
    if (data && data.success === true) return { ok: true };
    const codes = (data && data['error-codes']) || ['unknown'];
    for (const c of codes) ERROR_TTL.set(c, (ERROR_TTL.get(c) || 0) + 1);
    if (logger) logger({ event: 'turnstile_rejected', codes });
    return { ok: false, code: String(codes[0]) };
  } catch (err) {
    recordFallback({ provider: 'turnstile', reason: 'fail_open' });
    if (logger) logger({ event: 'turnstile_failopen', message: String((err && err.message) || err) });
    return { ok: true, failOpen: true };
  }
}
