import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const IDENTITY_ROUTES = [
  {
    method: 'post', path: '/identity/nik/validate', action: 'IDV_NIK_VALIDATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'nikHash', pattern: PATTERNS.REF_VALUE_CODE, required: true },
      { name: 'nikLast4', pattern: PATTERNS.KEY, required: true },
      { name: 'verdict', pattern: PATTERNS.NAME, required: true },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/identity/ktp/ocr', action: 'IDV_KTP_OCR_RESULT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'verdict', pattern: PATTERNS.NAME, required: true },
      { name: 'reason', pattern: PATTERNS.NAME, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/identity/kyc/status', action: 'IDV_STATUS',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/identity/kyc/apply', action: 'IDV_APPLY',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/identity/reviews/decide', action: 'IDV_REVIEW_DECIDE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'reviewId', pattern: PATTERNS.INT, required: true },
      { name: 'decision', pattern: PATTERNS.NAME, required: true },
      { name: 'reason', pattern: PATTERNS.NAME, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
];
