// Free-tier SMS adapter (PR-082, hardened PR-086): generic HTTP SMS relay
// driven entirely by env, sent via resilientFetch (4s timeout, retry only
// 429/5xx/network, per-provider breaker). Absent config fails closed with a
// named error (never faked as sent). HTTP failures reject so the caller can
// fall back to manual review.
import { resilientFetch, DEFAULT_TIMEOUT_MS } from '../resilience.js';

export async function sendFreeSms(
  { to, text, idempotencyKey = null },
  { fetchImpl = fetch, timeoutMs = Number(process.env.FREE_SMS_TIMEOUT_MS || DEFAULT_TIMEOUT_MS) } = {},
) {
  const endpoint = process.env.FREE_SMS_ENDPOINT;
  const apiKey = process.env.FREE_SMS_API_KEY;
  if (!endpoint || !apiKey) {
    throw new Error('FREE_SMS_ENDPOINT/FREE_SMS_API_KEY are not set');
  }
  const res = await resilientFetch(
    'free_sms',
    endpoint,
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        to,
        text,
        from: process.env.FREE_SMS_SENDER || 'cobol-banking',
      }),
    },
    { fetchImpl, timeoutMs, idempotencyKey },
  );
  if (!res.ok) throw new Error(`free-sms send failed: HTTP ${res.status}`);
  return true;
}
