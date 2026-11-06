// Optional nusakit-style HTTP adapter (PR-083): only active with explicit
// consent + allowlisted endpoint. Timeouts in 3s and falls back to local
// structural validation. Never sends the NIK anywhere except the configured
// endpoint, and only when the caller passes consent: true.
import { parseNik } from './local_nik.js';

const DEFAULT_TIMEOUT_MS = 3000;

export async function validateNikRemote(
  { nik, consent = false },
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
    const res = await fetchImpl(endpoint, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ nik }),
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const body = await res.json();
    return { ...local, remote: body && body.verdict ? body.verdict : 'unknown' };
  } catch (err) {
    return { ...local, remote: `fallback (${String((err && err.message) || err)})` };
  }
}
