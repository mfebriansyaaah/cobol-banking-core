import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const PROCUREMENT_ROUTES = [
  { method: 'post', path: '/procurement/requests', action: 'PRC_REQUEST_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'item', pattern: PATTERNS.RPT_NAME, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/procurement/requests', action: 'PRC_REQUEST_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.PRC_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/procurement/requests/:id/approve', action: 'PRC_REQUEST_APPROVE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/procurement/requests/:id/reject', action: 'PRC_REQUEST_REJECT', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/procurement/requests/:id/order', action: 'PRC_REQUEST_ORDER', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/procurement/summary', action: 'PRC_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
