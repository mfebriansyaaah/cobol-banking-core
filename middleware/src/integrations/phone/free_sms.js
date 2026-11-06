// Free-tier SMS adapter (PR-082, optional): generic HTTP SMS relay driven
// entirely by env (endpoint, key, sender id). No provider is hardcoded;
// configure any free-tier relay that accepts a JSON POST. Absent config
// fails closed with a named error (never faked as sent).
export async function sendFreeSms({ to, text }) {
  const endpoint = process.env.FREE_SMS_ENDPOINT;
  const apiKey = process.env.FREE_SMS_API_KEY;
  if (!endpoint || !apiKey) {
    throw new Error('FREE_SMS_ENDPOINT/FREE_SMS_API_KEY are not set');
  }
  const res = await fetch(endpoint, {
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
    signal: AbortSignal.timeout(Number(process.env.FREE_SMS_TIMEOUT_MS || 10000)),
  });
  if (!res.ok) throw new Error(`free-sms send failed: HTTP ${res.status}`);
  return true;
}
