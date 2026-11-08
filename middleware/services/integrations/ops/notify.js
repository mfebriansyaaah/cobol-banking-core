// Ops alerts (PR-095): Telegram/ntfy fan-out for dead letters, failed
// backups, migration errors, pool saturation. IDs and statuses only —
// never PII, never secrets, never message bodies. Best-effort with a
// timeout: alert delivery must not fail the job that raised it.
import { DEFAULT_TIMEOUT_MS } from '../resilience.js';

function targets() {
  const list = [];
  if (process.env.ALERT_TELEGRAM_CHAT_ID && process.env.TELEGRAM_BOT_TOKEN) {
    list.push({ kind: 'telegram', chatId: process.env.ALERT_TELEGRAM_CHAT_ID });
  }
  if (process.env.ALERT_NTFY_TOPIC) list.push({ kind: 'ntfy', topic: process.env.ALERT_NTFY_TOPIC });
  return list;
}

export function alertTargets() {
  return targets().map((t) => t.kind);
}

async function postJson(fetchImpl, url, payload, timeoutMs, headers = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetchImpl(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...headers },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    return res.ok;
  } finally {
    clearTimeout(timer);
  }
}

// event: short code (e.g. OUTBOX_DEAD); detail: ids/statuses only.
export async function sendAlert(
  event,
  detail = {},
  { fetchImpl = fetch, timeoutMs = Number(process.env.ALERT_TIMEOUT_MS || DEFAULT_TIMEOUT_MS), logger = null } = {},
) {
  const text = `[cobol-banking] ${event} ${JSON.stringify(detail).slice(0, 300)}`;
  const results = {};
  for (const t of targets()) {
    try {
      if (t.kind === 'telegram') {
        const token = process.env.TELEGRAM_BOT_TOKEN;
        const base = process.env.TELEGRAM_API_BASE || 'https://api.telegram.org';
        results.telegram = await postJson(
          fetchImpl,
          `${base}/bot${token}/sendMessage`,
          { chat_id: t.chatId, text },
          timeoutMs,
        );
      } else {
        const server = process.env.NTFY_SERVER || 'https://ntfy.sh';
        results.ntfy = await postJson(
          fetchImpl,
          `${server}/${t.topic}`,
          { topic: t.topic, message: text, title: event },
          timeoutMs,
        );
      }
    } catch (err) {
      results[t.kind] = false;
      if (logger) logger({ event: 'alert_failed', kind: t.kind, message: String((err && err.message) || err) });
    }
  }
  if (logger) logger({ event: 'alert_sent', alert: event, results });
  return results;
}
