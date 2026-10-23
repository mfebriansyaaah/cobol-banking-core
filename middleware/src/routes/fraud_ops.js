import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const FRAUD_OPS_ROUTES = [
  { method: 'post', path: '/fraud/reviews', action: 'FOP_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'caseRef', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'score', pattern: PATTERNS.INT, required: false },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/fraud/reviews', action: 'FOP_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.FOP_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/fraud/reviews/:id/review', action: 'FOP_REVIEW', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/fraud/reviews/:id/clear', action: 'FOP_CLEAR', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/fraud/reviews/:id/block', action: 'FOP_BLOCK', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/fraud/summary', action: 'FOP_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
