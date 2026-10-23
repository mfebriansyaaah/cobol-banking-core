import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const SANCTIONS_HOLD_ROUTES = [
  { method: 'post', path: '/sanctions/holds', action: 'SHL_HOLD_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'customer', pattern: PATTERNS.EMAIL, required: true },
    { name: 'reason', pattern: PATTERNS.BATCH_DETAIL, required: true },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/sanctions/holds', action: 'SHL_HOLD_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.BATCH_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/sanctions/holds/:id/release', action: 'SHL_HOLD_RELEASE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/sanctions/summary', action: 'SHL_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
