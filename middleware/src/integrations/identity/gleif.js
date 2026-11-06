// GLEIF LEI lookup (PR-097): free global corporate registry. Cache-only
// signal for onboarding triage — never a substitute for AHU/akta, never a
// claim of Indonesian registration. Failures reject (caller falls back to
// manual input); no PII beyond the queried legal name, nothing logged raw.
import { resilientFetch } from '../resilience.js';

export const DEFAULT_TIMEOUT_MS = 3000;

export const DEFAULT_ENDPOINT = 'https://api.gleif.org/api/v1';

export function isLei(s) {
  return /^[0-9A-Z]{20}$/.test(String(s ?? ''));
}

export async function lookupLei(
  lei,
  {
    fetchImpl = fetch,
    timeoutMs = Number(process.env.GLEIF_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
    endpoint = process.env.GLEIF_ENDPOINT || DEFAULT_ENDPOINT,
    idempotencyKey = null,
  } = {},
) {
  if (!isLei(lei)) return { result: 'INVALID_INPUT', entity: null };
  const res = await resilientFetch(
    'gleif',
    `${endpoint}/lei-records/${lei}`,
    { method: 'GET', headers: { accept: 'application/vnd.api+json' } },
    { fetchImpl, timeoutMs, idempotencyKey },
  );
  if (res.status === 404) return { result: 'NOT_FOUND', entity: null };
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  let body;
  try {
    body = await res.json();
  } catch {
    throw new Error('malformed JSON');
  }
  const attrs = (body && body.data && body.data.attributes) || null;
  if (!attrs || !attrs.entity || !attrs.entity.legalName) throw new Error('unexpected shape');
  return {
    result: 'FOUND',
    entity: {
      lei,
      legalName: String(attrs.entity.legalName.name || '').slice(0, 255),
      status: String((attrs.registration && attrs.registration.status) || 'UNKNOWN').slice(0, 32),
      address: String(((attrs.entity.legalAddress || {}).city) || '').slice(0, 255) || null,
      parentLei: null,
    },
  };
}

export async function searchLeis(
  name,
  {
    fetchImpl = fetch,
    timeoutMs = Number(process.env.GLEIF_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
    endpoint = process.env.GLEIF_ENDPOINT || DEFAULT_ENDPOINT,
  } = {},
) {
  const q = String(name ?? '').trim();
  if (!q) return { result: 'INVALID_INPUT', matches: [] };
  const res = await resilientFetch(
    'gleif',
    `${endpoint}/lei-records?filter%5Bentity.legalName%5D=${encodeURIComponent(q)}&page%5Bsize%5D=5`,
    { method: 'GET', headers: { accept: 'application/vnd.api+json' } },
    { fetchImpl, timeoutMs },
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  let body;
  try {
    body = await res.json();
  } catch {
    throw new Error('malformed JSON');
  }
  const rows = Array.isArray(body.data) ? body.data : [];
  return {
    result: 'FOUND',
    matches: rows.slice(0, 5).map((r) => ({
      lei: r.id,
      legalName: String((r.attributes?.entity?.legalName?.name) || '').slice(0, 255),
      status: String(r.attributes?.registration?.status || 'UNKNOWN').slice(0, 32),
    })),
  };
}

export function createCorporateProvider(kind, { logger = null } = {}) {
  void logger;
  if (kind === 'mock') {
    return {
      kind,
      async lookup() {
        return { result: 'NOT_FOUND', entity: null };
      },
      async health() {
        return { ok: true, provider: 'mock', detail: null };
      },
    };
  }
  if (kind === 'gleif') {
    return {
      kind,
      async lookup(lei, opts) {
        return lookupLei(lei, opts);
      },
      async search(name, opts) {
        return searchLeis(name, opts);
      },
      async health() {
        return { ok: true, provider: 'gleif', detail: null };
      },
    };
  }
  throw new Error(`unknown corporate provider '${kind}' (mock|gleif)`);
}
