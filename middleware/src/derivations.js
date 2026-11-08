// Server-side derivations (gateway service, not business rules).
// Converts raw client input into the derived values COBOL stores, so the
// gateway never accepts verdicts, hashes, or risk signals from the client.
// Each derivation validates its raw inputs with PATTERNS (throwing
// ValidationError like buildParams) and computes derived fields via the
// integration services. Derivations never invoke COBOL: they only reshape
// input before buildParams maps it onto the 6 positional slots.
import { createHash, randomUUID } from 'node:crypto';
import { PATTERNS, ValidationError, check } from './validation.js';
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

// NIK validation: structural verdict + HMAC handle computed here. The raw
// NIK never reaches COBOL, the database, or logs — only hmac + last4 travel.
export async function deriveNik(input) {
  const nik = required(input, 'nik', PATTERNS.NIK);
  const structural = parseNik(nik);
  const secret = process.env.NIK_HMAC_SECRET || '';
  if (!secret) throw new Error('NIK_HMAC_SECRET is not set');
  const handle = nikHandle(nik, secret);
  return {
    nikHash: handle.hmac,
    nikLast4: handle.last4,
    verdict: structural.valid ? 'VALID' : 'INVALID',
  };
}

// Screening: name (+ optional dob) with explicit consent. The adapter verdict
// is recorded owner-side; reviewer verdicts stay SUPER_ADMIN-only in COBOL.
// Without consent the check cannot run, so the request is rejected.
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
      return {
        queryHash: queryHash(name, dob),
        result: 'MANUAL_REVIEW',
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
  return { queryHash: res.queryHash, result: res.result, provider: kind, providerRef };
}

// KTP OCR: the adapter never clears — approval stays human-only in COBOL.
// Every outcome maps to MANUAL_REVIEW (or REJECTED is reserved for a future
// real OCR); provider failure also opens a review, never auto-approves.
export async function deriveOcr(input) {
  const imageRef = required(input, 'imageRef', PATTERNS.KEY);
  const kind = (process.env.KTP_OCR_PROVIDER || 'mock').trim().toLowerCase();
  const ocr = createOcrProvider(kind);
  try {
    const r = await ocr.extractKtp({ imageRef });
    const confidence = Number(r && r.confidence);
    if (!r || r.ok !== true || r.needsReview || !Number.isFinite(confidence) || confidence < OCR_REVIEW_THRESHOLD) {
      return { verdict: 'MANUAL_REVIEW', reason: 'low-confidence' };
    }
    return { verdict: 'MANUAL_REVIEW', reason: 'human-review-required' };
  } catch {
    return { verdict: 'MANUAL_REVIEW', reason: 'provider-unavailable' };
  }
}

// Risk notation: IP resolved and hashed server-side from the request socket.
// The raw IP never reaches COBOL or the database — only ip_hash travels.
export async function deriveRisk(input, ctx = {}) {
  const email = required(input, 'email', PATTERNS.EMAIL);
  const ip = (ctx.req && ctx.req.ip) || '';
  if (!ip) throw new Error('client IP unavailable');
  const r = await noteRisk({ email, ip, lastCountry: null });
  return {
    country: r.country,
    city: r.city ?? '',
    asn: r.asn ?? '',
    ipHashFlags: r.flags ? `${r.ipHash}:${r.flags}` : r.ipHash,
  };
}

// Phone linking: normalize to E.164 and hash server-side so the stored
// handle is canonical. Raw numbers never persist (phone_links holds the hash).
export async function derivePhoneHash(input) {
  const phone = required(input, 'phone', PATTERNS.PHONE);
  const normalized = normalizeIdPhone(phone);
  if (!normalized) throw new ValidationError('phone');
  return { phoneHash: createHash('sha256').update(normalized).digest('hex') };
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
