// Telegram OTP channel (PR-082): Bot API sendMessage, no dependencies.
// The caller supplies the chat_id (phone->chat binding lands with the
// phone_links table in the 082b commit); this module only delivers.
// Failures reject so the caller can mark rows FAILED (unlike the mock,
// real delivery is never faked as success).
export async function sendTelegramOtp({ chatId, text, token }) {
  const botToken = token ?? process.env.TELEGRAM_BOT_TOKEN;
  if (!botToken) throw new Error('TELEGRAM_BOT_TOKEN is not set');
  if (!chatId) throw new Error('chat_id is required (link the phone first)');
  const res = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text }),
    signal: AbortSignal.timeout(Number(process.env.TELEGRAM_TIMEOUT_MS || 10000)),
  });
  if (!res.ok) throw new Error(`telegram send failed: HTTP ${res.status}`);
  const body = await res.json();
  if (!body || body.ok !== true) throw new Error('telegram send rejected');
  return true;
}
