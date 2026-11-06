// Sanctions/PEP screening adapter (PR-090): yente-compatible HTTP match
// with OFAC/UN/EU list fallback, fail-closed to MANUAL_REVIEW.
// - Sends name + birth year only (never NIK); query terms hashed for audit.
// - No matches -> CLEAR; any match -> POTENTIAL_MATCH (a reviewer confirms
//   or false-positives via SCR_SCREEN; the adapter never clears).
// - Provider down/malformed/timeout -> list fallback if configured, else
//   MANUAL_REVIEW (never CLEAR on doubt). License: OpenSanctions data is
//   non-commercial unless SCREENING_LICENSE=commercial with a key.
import { createHash } from 'node:crypto';
import { recordFallback, resilientFetch, DEFAULT_TIMEOUT_MS } from '../resilience.js';
import { matchLists } from './lists.js';
import { createMockScreening } from './mock.js';

export function queryHash(name, dob) {
  return createHash('sha256')
    .update(`${String(name).trim().toLowerCase()}|${String(dob ?? '')}`)
    .digest('hex');
}

export function assertScreeningLicense() {
  const mode = (process.env.SCREENING_LICENSE || 'noncommercial').trim().toLowerCase();
  if (mode === 'commercial' && !process.env.SCREENING_LICENSE_KEY) {
    throw new Error('SCREENING_LICENSE=commercial needs SCREENING_LICENSE_KEY');
  }
  if (!['noncommercial', 'commercial'].includes(mode)) {
    throw new Error(`invalid SCREENING_LICENSE=${JSON.stringify(mode)} (noncommercial|commercial)`);
  }
  return mode;
}

function maxScore(body) {
  const lists = [];
  if (Array.isArray(body.matches)) lists.push(...body.matches);
  if (Array.isArray(body.results)) lists.push(...body.results);
  let best = 0;
  let ref = null;
  for (const m of lists) {
    const s = Number(m.score ?? m.match ?? 0);
    if (Number.isFinite(s) && s > best) {
      best = s;
      ref = String(m.id ?? m.entity_id ?? m.caption ?? 'match');
    }
  }
  return { best, ref };
}

export async function screenName(
  { name, dob = null, consent = false, idempotencyKey = null },
  {
    fetchImpl = fetch,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    endpoint = process.env.SCREENING_ENDPOINT,
    allowlist = (process.env.SCREENING_ALLOWLIST || '').split(',').filter(Boolean),
  } = {},
) {
  const clean = String(name ?? '').trim();
  if (!clean) return { result: 'INVALID_INPUT', score: null, ref: null, queryHash: null };
  const hash = queryHash(clean, dob);
  if (!consent) return { result: 'SKIPPED', score: null, ref: null, queryHash: hash };
  if (!endpoint || !allowlist.some((host) => endpoint.includes(host))) {
    return { result: 'SKIPPED', score: null, ref: null, queryHash: hash };
  }
  assertScreeningLicense();
  try {
    const res = await resilientFetch(
      'opensanctions',
      `${endpoint}/match`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ name: clean, birth_year: dob ? String(dob).slice(0, 4) : undefined }),
      },
      { fetchImpl, timeoutMs, idempotencyKey },
    );
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    let body;
    try {
      body = await res.json();
    } catch {
      throw new Error('malformed JSON');
    }
    const { best, ref } = maxScore(body || {});
    if (best <= 0) return { result: 'CLEAR', score: 0, ref: null, queryHash: hash };
    return { result: 'POTENTIAL_MATCH', score: best, ref, queryHash: hash };
  } catch (err) {
    const listed = matchLists(clean);
    if (listed) {
      recordFallback({ provider: 'opensanctions', reason: 'lists' });
      return { ...listed, queryHash: hash };
    }
    recordFallback({ provider: 'opensanctions', reason: 'manual_review' });
    return {
      result: 'MANUAL_REVIEW',
      score: null,
      ref: `fallback (${String((err && err.message) || err)})`,
      queryHash: hash,
    };
  }
}

export function createScreeningProvider(kind, { logger = null } = {}) {
  if (kind === 'mock') return createMockScreening({ logger });
  if (kind === 'opensanctions') {
    return {
      kind,
      async screen(args, opts) {
        return screenName(args, opts);
      },
      async health() {
        if (!process.env.SCREENING_ENDPOINT) {
          return { ok: false, provider: 'opensanctions', detail: 'SCREENING_ENDPOINT missing' };
        }
        return { ok: true, provider: 'opensanctions', detail: null };
      },
    };
  }
  throw new Error(`unknown screening provider '${kind}' (mock|opensanctions)`);
}
