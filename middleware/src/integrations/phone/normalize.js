// Indonesian E.164 normalization (PR-082): dependency-free, ID-only.
// 08xx -> +62xx, leading 62/+, spaces/dashes stripped. Returns null when
// the digits cannot form a plausible MSISDN (too short/long).
export function normalizeIdPhone(raw) {
  const digits = String(raw ?? '').replace(/\D/g, '');
  let national = digits;
  if (national.startsWith('62')) national = national.slice(2);
  else if (national.startsWith('0')) national = national.slice(1);
  if (!/^[1-9]\d{7,12}$/.test(national)) return null;
  return `+62${national}`;
}
