// Geo-IP risk signal (PR-092): ipapi-compatible HTTP lookup with private-IP
// short-circuit. Fail-open to UNKNOWN (a signal, never a gate): missing
// endpoint, timeout, malformed body, or private/unknown address all resolve
// UNKNOWN without throwing. Raw IPs never leave the caller (see
// risk_events.js for hashing); logs carry the hash only.
import { resilientFetch, DEFAULT_TIMEOUT_MS } from '../resilience.js';

export function isPrivateIp(ip) {
  const s = String(ip ?? '').trim();
  if (!s) return true;
  if (s === '::1' || s.toLowerCase() === 'localhost') return true;
  const v4 = s.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!v4) return false;
  const [a, b] = [Number(v4[1]), Number(v4[2])];
  return a === 10 || a === 127 || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168);
}

export async function resolveGeo(
  ip,
  {
    fetchImpl = fetch,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    endpoint = process.env.GEOIP_ENDPOINT,
    idempotencyKey = null,
  } = {},
) {
  if (!ip || isPrivateIp(ip)) return { country: 'UNKNOWN', city: null, asn: null };
  if (!endpoint) return { country: 'UNKNOWN', city: null, asn: null };
  try {
    const res = await resilientFetch(
      'geoip',
      `${endpoint}/${encodeURIComponent(String(ip).trim())}/json/`,
      { method: 'GET' },
      { fetchImpl, timeoutMs, idempotencyKey },
    );
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    let body;
    try {
      body = await res.json();
    } catch {
      throw new Error('malformed JSON');
    }
    const country = /^[A-Z]{2}$/.test(body.country_code || '') ? body.country_code : 'UNKNOWN';
    return {
      country,
      city: typeof body.city === 'string' && body.city ? body.city.slice(0, 64) : null,
      asn: typeof body.asn === 'string' && body.asn ? body.asn.slice(0, 32) : null,
    };
  } catch {
    return { country: 'UNKNOWN', city: null, asn: null };
  }
}

export function createGeoProvider(kind, { logger = null } = {}) {
  void logger;
  if (kind === 'mock' || kind === 'ipapi') {
    return {
      kind,
      async resolve(args, opts) {
        return resolveGeo(args?.ip, opts);
      },
      async health() {
        if (kind === 'mock') return { ok: true, provider: 'mock', detail: null };
        if (!process.env.GEOIP_ENDPOINT) {
          return { ok: false, provider: 'ipapi', detail: 'GEOIP_ENDPOINT missing' };
        }
        return { ok: true, provider: 'ipapi', detail: null };
      },
    };
  }
  throw new Error(`unknown geo provider '${kind}' (mock|ipapi)`);
}
