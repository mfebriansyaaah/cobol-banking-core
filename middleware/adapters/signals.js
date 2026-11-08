// Canonical adapter signals (ADR-0006, Option A).
// Owner: middleware/adapters. Converts raw client input into internal
// signals for COBOL, so the gateway never accepts verdicts, hashes, or risk
// signals from the client. Adapters may classify provider output, but domain
// state transitions remain in COBOL (NIK_VALID, SCREEN_RECORDED + review,
// RISK_NOTED, LINK_BEGIN, OCR_RECORDED).
//
// Signal naming: `*Signal` / `*Valid` fields are the adapter classification.
// Legacy COBOL field names (`verdict`, `result`, `ipHashFlags`) are kept as
// aliases so the 6-slot pipe contract does not break. `middleware/src/app.js`
// maps signals → COBOL params; COBOL decides the final status.
// middleware/src/derivations.js re-exports this module for backward compat.
import { createHash, randomUUID } from 'node:crypto';
import { PATTERNS, ValidationError, check } from '../src/validation.js';
import { parseNik, nikHandle } from '../services/integrations/identity/local_nik.js';
import { createScreeningProvider, queryHash } from '../services/integrations/screening/opensanctions.js';
import { createOcrProvider, OCR_REVIEW_THRESHOLD } from '../services/integrations/ocr.js';
import { noteRisk } from '../services/integrations/risk/risk_events.js';
import { normalizeIdPhone } from '../services/integrations/phone/normalize.js';
import { assertQuota, recordUse } from '../services/integrations/quota.js';

function required(input, name, pattern) {
  const value = input[name];
  if (value === undefined || value === '') throw new ValidationError(name);
  return check(String(value), pattern, name);
}

// NIK: structural signal + HMAC handle. Raw NIK never reaches COBOL, DB, logs.
export async function deriveNik(input) {
  const nik = required(input, 'nik', PATTERNS.NIK);
  const structural = parseNik(nik);
  const secret = process.env.NIK_HMAC_SECRET || '';
  if (!secret) throw new Error('NIK_HMAC_SECRET is not set');
  const handle = nikHandle(nik, secret);
  const signal = structural.valid ? 'VALID' : 'INVALID';
  return {
    nikHash: handle.hmac,
    nikLast4: handle.last4,
    // Signal (adapter classification). COBOL decides NIK_VALID vs kyc_status.
    nikStructuralValid: signal,
    // Legacy alias for the 6-slot COBOL contract (same value as signal).
    verdict: signal,
  };
}

// Screening: provider signal, fail-closed to MANUAL_REVIEW. COBOL opens the
// human review row; reviewer verdicts stay SUPER_ADMIN-only in COBOL.
export async function deriveScreen(input, ctx = {}) {
  const rawName = required(input, 'name', PATTERNS.NAME);
  const name = rawName.trim();
  if (!name) throw new ValidationError('name');
  const dob = input.dob === undefined || input.dob === '' ? null : check(String(input.dob), PATTERNS.DATE, 'dob');
  if (String(input.consent ?? '') !== '1') throw new ValidationError('consent');
  const kind = (process.env.SCREENING_PROVIDER || 'mock').trim().toLowerCase();
  const provider = createScreeningProvider(kind);
  if (kind !== 'mock') {
    try {
      assertQuota(kind);
    } catch {
      // Over budget: fail closed into the review queue, never CLEAR on doubt.
      const fallback = 'MANUAL_REVIEW';
      return {
        queryHash: queryHash(name, dob),
        providerResultSignal: fallback,
        result: fallback,
        provider: kind,
        providerRef: 'quota-exceeded',
      };
    }
  }
  const idempotencyKey = (ctx.req && ctx.req.requestId) || randomUUID();
  const res = await provider.screen({ name, dob, consent: true, idempotencyKey });
  if (!res || res.result === 'SKIPPED' || res.result === 'INVALID_INPUT' || !res.queryHash) {
    throw new Error('screening provider not configured');
  }
  if (res.result !== 'CLEAR' && res.result !== 'POTENTIAL_MATCH' && res.result !== 'MANUAL_REVIEW') {
    throw new Error(`unexpected screening result: ${res.result}`);
  }
  if (kind !== 'mock') recordUse(kind);
  const providerRef = String(res.ref ?? '')
    .replace(/[^A-Za-z0-9_.:-]/g, '_')
    .slice(0, 64);
  return {
    queryHash: res.queryHash,
    providerResultSignal: res.result,
    result: res.result,
    provider: kind,
    providerRef,
  };
}

// KTP OCR: adapter never clears — approval stays human-only in COBOL.
export async function deriveOcr(input) {
  const imageRef = required(input, 'imageRef', PATTERNS.KEY);
  const kind = (process.env.KTP_OCR_PROVIDER || 'mock').trim().toLowerCase();
  const ocr = createOcrProvider(kind);
  const toSignal = (reason) => ({
    ocrReviewSignal: 'MANUAL_REVIEW',
    verdict: 'MANUAL_REVIEW',
    reason,
  });
  try {
    const r = await ocr.extractKtp({ imageRef });
    const confidence = Number(r && r.confidence);
    if (!r || r.ok !== true || r.needsReview || !Number.isFinite(confidence) || confidence < OCR_REVIEW_THRESHOLD) {
      return toSignal('low-confidence');
    }
    return toSignal('human-review-required');
  } catch {
    return toSignal('provider-unavailable');
  }
}

// Risk: IP resolved/hashed server-side from socket. Raw IP never travels.
export async function deriveRisk(input, ctx = {}) {
  const email = required(input, 'email', PATTERNS.EMAIL);
  const ip = (ctx.req && ctx.req.ip) || '';
  if (!ip) throw new Error('client IP unavailable');
  const r = await noteRisk({ email, ip, lastCountry: null });
  const flagsSignal = r.flags ?? '';
  return {
    country: r.country,
    city: r.city ?? '',
    asn: r.asn ?? '',
    ipHash: r.ipHash,
    riskFlagsSignal: flagsSignal,
    // Legacy alias: colon-joined for the single pipe-safe COBOL slot.
    ipHashFlags: flagsSignal ? `${r.ipHash}:${flagsSignal}` : r.ipHash,
  };
}

// Phone linking: E.164 signal hashed server-side. Raw never persists.
export async function derivePhoneHash(input) {
  const phone = required(input, 'phone', PATTERNS.PHONE);
  const normalized = normalizeIdPhone(phone);
  if (!normalized) throw new ValidationError('phone');
  return {
    phoneE164Signal: normalized,
    phoneHash: createHash('sha256').update(normalized).digest('hex'),
  };
}

export const DERIVATIONS = {
  IDV_NIK_VALIDATE: deriveNik,
  IDV_KTP_OCR_RESULT: deriveOcr,
  SCR_SCREEN: deriveScreen,
  RISK_NOTE: deriveRisk,
  OTP_LINK_BEGIN: derivePhoneHash,
};

export async function applyDerivation(action, input, ctx = {}) {
  const fn = DERIVATIONS[action];
  if (!fn) return {};
  return fn(input, ctx);
}
