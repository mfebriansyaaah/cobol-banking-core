// Local structural NIK validation (PR-083): fully offline, no personal
// data leaves the process. This is STRUCTURAL validation, never
// Dukcapil verification (see docs/IDENTITY.md).
// Response: { valid, level: 'STRUCTURAL', region, gender, age, reason? }.
import { readFileSync } from 'node:fs';
import { createHmac } from 'node:crypto';

// Vendored 2022 snapshot (wilayah@1.3.0 MIT): 34 provinces, 514 regencies.
// Loaded from disk (not bundled import attributes) for parser compatibility.
const wilayah = JSON.parse(readFileSync(new URL('./data/wilayah.json', import.meta.url), 'utf8'));

// Storage handle for a validated NIK: HMAC-SHA256 with a server secret plus
// the last 4 for display. Raw NIKs are never persisted (PR-083).
export function nikHandle(nik, secret) {
  const s = String(nik ?? '');
  if (!secret) throw new Error('nikHandle needs a server secret');
  return {
    last4: s.slice(-4),
    hmac: createHmac('sha256', String(secret)).update(s).digest('hex'),
  };
}

export function parseNik(nik, asOf = new Date()) {
  const s = String(nik ?? '');
  if (!/^\d{16}$/.test(s)) return { valid: false, reason: 'must be 16 digits' };
  const provCode = s.slice(0, 2);
  const regCode = s.slice(0, 4);
  const province = wilayah.provinces[provCode] || null;
  if (!province) return { valid: false, reason: 'unknown province code' };
  const regency = wilayah.regencies[regCode] || null;
  if (!regency) return { valid: false, reason: 'unknown regency code' };
  let day = Number(s.slice(6, 8));
  let gender = 'male';
  if (day > 40) {
    day -= 40;
    gender = 'female';
  }
  const month = Number(s.slice(8, 10));
  const year2 = Number(s.slice(10, 12));
  if (day < 1 || day > 31 || month < 1 || month > 12) {
    return { valid: false, reason: 'bad birth-date segment' };
  }
  // Resolve century against the reference date (00-99 sliding window).
  const refYear = asOf.getFullYear();
  let year = Math.floor(refYear / 100) * 100 + year2;
  if (year > refYear) year -= 100;
  const dob = new Date(Date.UTC(year, month - 1, day));
  if (dob.getUTCMonth() !== month - 1 || dob.getUTCDate() !== day) {
    return { valid: false, reason: 'nonexistent calendar date' };
  }
  let age = refYear - year;
  const hadBirthday = asOf.getMonth() + 1 > month || (asOf.getMonth() + 1 === month && asOf.getDate() >= day);
  if (!hadBirthday) age -= 1;
  const minAge = Number(process.env.NIK_MIN_AGE || 17);
  if (age < minAge) return { valid: false, reason: `under ${minAge} (KYC minimum)` };
  if (s.slice(12, 16) === '0000') return { valid: false, reason: 'zero serial' };
  return {
    valid: true,
    level: 'STRUCTURAL',
    region: { province, regency },
    gender,
    age,
    reason: null,
  };
}
