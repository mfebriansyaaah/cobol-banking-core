// Telegram OTP channel (PR-082, hardened PR-086): Bot API sendMessage via
// resilientFetch (4s timeout, retry only 429/5xx/network, per-provider
// circuit breaker). Failures reject with named errors so the caller can fall
// back to free SMS / manual review (never faked as success). Malformed JSON
// or a rejected body is terminal (no retry: the send happened).
import { resilientFetch, DEFAULT_TIMEOUT_MS } from '../resilience.js';

export async function sendTelegramOtp(
  { chatId, text, token, idempotencyKey = null },
  {
    fetchImpl = fetch,
    timeoutMs = Number(process.env.TELEGRAM_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
    // Test seam (PR-088): point at the local fake. Production default is the
    // real Bot API; CI never sets this to a real host.
    baseUrl = process.env.TELEGRAM_API_BASE || 'https://api.telegram.org',
  } = {},
) {
  const botToken = token ?? process.env.TELEGRAM_BOT_TOKEN;
  if (!botToken) throw new Error('TELEGRAM_BOT_TOKEN is not set');
  if (!chatId) throw new Error('chat_id is required (link the phone first)');
  const res = await resilientFetch(
    'telegram',
    `${baseUrl}/bot${botToken}/sendMessage`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ chat_id: chatId, text }),
    },
    { fetchImpl, timeoutMs, idempotencyKey },
  );
  if (!res.ok) throw new Error(`telegram send failed: HTTP ${res.status}`);
  let body;
  try {
    body = await res.json();
  } catch {
    throw new Error('telegram send rejected (malformed JSON)');
  }
  if (!body || body.ok !== true) throw new Error('telegram send rejected');
  return true;
}
