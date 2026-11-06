// Optional nusakit-style HTTP adapter (PR-083, hardened PR-086): only active
// with explicit consent + allowlisted endpoint. Remote calls go through
// resilientFetch (3s timeout, retry only 429/5xx/network, per-provider
// breaker); every failure mode — skipped, error status, malformed JSON,
// timeout, circuit open — falls back to the local structural result so the
// user never hangs. Never sends the NIK anywhere except the configured
// endpoint, and only when the caller passes consent: true.
import { parseNik } from './local_nik.js';
import { recordFallback, resilientFetch } from '../resilience.js';

const DEFAULT_TIMEOUT_MS = 3000;

export async function validateNikRemote(
  { nik, consent = false, idempotencyKey = null },
  { fetchImpl = fetch, timeoutMs = DEFAULT_TIMEOUT_MS } = {},
) {
  const local = parseNik(nik);
  if (!local.valid) return local;
  const endpoint = process.env.NUSAKIT_ENDPOINT;
  const allowlist = (process.env.NUSAKIT_ALLOWLIST || '').split(',').filter(Boolean);
  if (!consent || !endpoint || !allowlist.some((host) => endpoint.includes(host))) {
    return { ...local, remote: 'skipped (no consent/endpoint/allowlist)' };
  }
  try {
    const res = await resilientFetch(
      'nusakit',
      endpoint,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ nik }),
      },
      { fetchImpl, timeoutMs, idempotencyKey },
    );
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    let body;
    try {
      body = await res.json();
    } catch {
      throw new Error('malformed JSON');
    }
    return { ...local, remote: body && body.verdict ? body.verdict : 'unknown' };
  } catch (err) {
    recordFallback({ provider: 'nusakit', reason: 'local' });
    return { ...local, remote: `fallback (${String((err && err.message) || err)})` };
  }
}
