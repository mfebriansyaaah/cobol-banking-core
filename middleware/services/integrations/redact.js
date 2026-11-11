// PII redaction for integrations (PR-087, UU PDP): structured log events
// must never carry raw NIK, phone, OTP code, token, or chat_id. Email `to`
// is kept by design (delivery ops need the recipient and the mailer suite
// locks it; the address is the account key, not a secret authenticator) —
// see docs/PRIVACY.md for the full policy and the per-field table.
const NIK_RUN = /\d{16}/;
const LAST4 = (s) =>
  String(s ?? '')
    .replace(/\D/g, '')
    .slice(-4);

// NIK -> asterisks + last4 (no 16-digit run survives).
export function redactNik(nik) {
  return `************${LAST4(nik)}`;
}

// Phone (E.164 or local) -> last4 only.
export function redactPhone(phone) {
  const last4 = LAST4(phone);
  return last4 ? `…${last4}` : '[redacted]';
}

// OTP codes and tokens never appear in logs, not even partially.
export function redactCode() {
  return '[redacted]';
}

export function redactToken() {
  return '[redacted]';
}

// Opaque chat ids are linkable identifiers: keep disambiguation, drop identity.
export function redactChatId(chatId) {
  const s = String(chatId ?? '');
  return s ? `…${s.slice(-4)}` : '[redacted]';
}

// Keys whose values are PII when present in a structured event.
const SENSITIVE_KEYS = new Set([
  'nik',
  'phone',
  'phoneNumber',
  'msisdn',
  'toPhone',
  'code',
  'otp',
  'otpCode',
  'token',
  'chatId',
  'chat_id',
]);

function scrubValue(key, value) {
  if (!SENSITIVE_KEYS.has(key)) return value;
  if (key === 'chatId' || key === 'chat_id') return redactChatId(value);
  if (key === 'code' || key === 'otp' || key === 'otpCode' || key === 'token') return '[redacted]';
  if (key === 'nik') return redactNik(value);
  return redactPhone(value);
}

// Shallow-scrub a structured log event. `to` is preserved only when it is an
// email address (mailer contract); a phone-looking `to` is redacted.
export function scrubEvent(event) {
  if (!event || typeof event !== 'object') return event;
  const out = { ...event };
  for (const key of Object.keys(out)) {
    if (key === 'to') {
      // Email recipients stay (mailer contract); phone-looking values scrub.
      if (typeof out[key] === 'string' && out[key].includes('@')) continue;
      out[key] = redactPhone(out[key]);
      continue;
    }
    out[key] = scrubValue(key, out[key]);
  }
  return out;
}

// Free-text scrub: NIK-shaped runs (16 consecutive digits) are the only safe
// blind pattern (shorter runs hit counts/ports/ids).
export function scrubText(text) {
  return String(text ?? '').replace(/\d{16}/g, '****************');
}

// Scanner for the privacy suite: returns human-readable findings, empty when
// clean. Checks structured events (sensitive keys with raw values) and free
// text (NIK-shaped runs).
export function scanForPii(event) {
  const findings = [];
  if (!event || typeof event !== 'object') {
    if (typeof event === 'string' && NIK_RUN.test(event)) findings.push('16-digit NIK run in text');
    return findings;
  }
  for (const [key, value] of Object.entries(event)) {
    if (typeof value !== 'string') continue;
    if (key === 'to' && value.includes('@')) continue;
    if (
      SENSITIVE_KEYS.has(key) &&
      value !== '[redacted]' &&
      value !== 'redacted' &&
      !value.startsWith('…') &&
      !value.startsWith('************')
    ) {
      findings.push(`raw PII in key '${key}'`);
    }
    if (NIK_RUN.test(value)) findings.push(`16-digit NIK run in key '${key}'`);
  }
  return findings;
}
