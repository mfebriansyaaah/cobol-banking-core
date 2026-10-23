import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const FEE_WAIVER_ROUTES = [
  { method: 'post', path: '/fee-waivers', action: 'FWV_WAIVER_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'feeType', pattern: PATTERNS.FEE_TYPE, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'reason', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/fee-waivers', action: 'FWV_WAIVER_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.FWV_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/fee-waivers/:id/approve', action: 'FWV_WAIVER_APPROVE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/fee-waivers/:id/reject', action: 'FWV_WAIVER_REJECT', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/fee-waivers/summary', action: 'FWV_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
