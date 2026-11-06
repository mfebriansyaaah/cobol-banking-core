// Healthchecks.io ping (PR-095): liveness signal at the end of cron-style
// jobs (outbox worker, drills). Best-effort: a failed ping never fails the
// job itself. No PII, only the check UUID in the URL.
import { DEFAULT_TIMEOUT_MS } from '../resilience.js';

export async function pingCheck(
  checkId,
  {
    fetchImpl = fetch,
    timeoutMs = Number(process.env.HEALTHCHECKS_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
    base = process.env.HEALTHCHECKS_BASE || 'https://hc-ping.com',
  } = {},
) {
  if (!checkId) return false;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetchImpl(`${base}/${checkId}`, { method: 'GET', signal: controller.signal });
      return res.ok;
    } finally {
      clearTimeout(timer);
    }
  } catch {
    return false;
  }
}

export async function pingFail(checkId, message, opts = {}) {
  if (!checkId) return false;
  const {
    fetchImpl = fetch,
    timeoutMs = Number(process.env.HEALTHCHECKS_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
    base = process.env.HEALTHCHECKS_BASE || 'https://hc-ping.com',
  } = opts;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetchImpl(`${base}/${checkId}/fail`, {
        method: 'POST',
        headers: { 'content-type': 'text/plain' },
        body: String(message || '').slice(0, 500),
        signal: controller.signal,
      });
      return res.ok;
    } finally {
      clearTimeout(timer);
    }
  } catch {
    return false;
  }
}
