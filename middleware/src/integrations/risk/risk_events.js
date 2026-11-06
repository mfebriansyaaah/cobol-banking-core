// Risk notation helper (PR-092): hash the IP, resolve geo, compute flags.
// Pure except resolveGeo (injectable for tests). The raw IP never reaches
// COBOL or logs — only ip_hash travels.
import { createHash } from 'node:crypto';
import { resolveGeo } from './geoip.js';

export function hashIp(ip) {
  return createHash('sha256')
    .update(String(ip ?? ''))
    .digest('hex');
}

export function flagMismatch(geo, lastCountry) {
  const flags = [];
  if (!geo || geo.country === 'UNKNOWN') flags.push('GEO_UNKNOWN');
  else if (lastCountry && lastCountry !== geo.country) flags.push('COUNTRY_MISMATCH');
  return flags;
}

export async function noteRisk({ email, ip, lastCountry = null, flags = [] } = {}, { resolve = resolveGeo } = {}) {
  if (!email || !ip) throw new Error('noteRisk needs email and ip');
  const geo = await resolve(ip);
  const auto = flagMismatch(geo, lastCountry);
  // Colon-joined: travels as one pipe-safe route param (REF_VALUE_CODE);
  // COBOL splits and stores comma-separated.
  return {
    email,
    country: geo.country,
    city: geo.city,
    asn: geo.asn,
    ipHash: hashIp(ip),
    flags: [...new Set([...flags, ...auto])].join(':'),
  };
}
