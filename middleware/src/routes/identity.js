import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const IDENTITY_ROUTES = [
  // NIK is validated and hashed server-side (derivations.js): the client
  // sends the raw NIK only, never nikHash/verdict (any such values in the
  // body are overwritten by the derivation before COBOL runs).
  {
    method: 'post',
    path: '/identity/nik/validate',
    action: 'IDV_NIK_VALIDATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'nikHash', pattern: PATTERNS.REF_VALUE_CODE, required: false },
      { name: 'nikLast4', pattern: PATTERNS.KEY, required: false },
      { name: 'verdict', pattern: PATTERNS.NAME, required: false },
      BLANK,
      ACTOR,
    ],
  },
  // KTP OCR verdicts are derived server-side from the provider result;
  // approval never auto-fires (manual review stays mandatory).
  {
    method: 'post',
    path: '/identity/ktp/ocr',
    action: 'IDV_KTP_OCR_RESULT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'verdict', pattern: PATTERNS.NAME, required: false },
      { name: 'reason', pattern: PATTERNS.NAME, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/identity/kyc/status',
    action: 'IDV_STATUS',
    tokenIdentity: 'actor',
    fields: [{ name: 'email', pattern: PATTERNS.EMAIL, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/identity/kyc/apply',
    action: 'IDV_APPLY',
    tokenIdentity: 'actor',
    fields: [{ name: 'email', pattern: PATTERNS.EMAIL, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/identity/reviews',
    action: 'IDV_REVIEW_LIST',
    tokenIdentity: 'actor',
    stepUp: true,
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/identity/reviews/decide',
    action: 'IDV_REVIEW_DECIDE',
    tokenIdentity: 'actor',
    stepUp: true,
    fields: [
      { name: 'reviewId', pattern: PATTERNS.INT, required: true },
      { name: 'decision', pattern: PATTERNS.NAME, required: true },
      { name: 'reason', pattern: PATTERNS.NAME, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
];
