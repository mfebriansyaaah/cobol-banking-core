import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const SCREENING_ROUTES = [
  {
    method: 'post',
    path: '/screening/check',
    action: 'SCR_SCREEN',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'queryHash', pattern: PATTERNS.REF_VALUE_CODE, required: true },
      { name: 'result', pattern: PATTERNS.NAME, required: true },
      { name: 'provider', pattern: PATTERNS.NAME, required: false },
      { name: 'providerRef', pattern: PATTERNS.REF_VALUE_CODE, required: false },
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/screening/status',
    action: 'SCR_STATUS',
    tokenIdentity: 'actor',
    fields: [{ name: 'email', pattern: PATTERNS.EMAIL, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/screening/reviews',
    action: 'IDV_REVIEW_LIST',
    tokenIdentity: 'actor',
    stepUp: true,
    fields: [BLANK, { name: 'kind', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/screening/reviews/decide',
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
