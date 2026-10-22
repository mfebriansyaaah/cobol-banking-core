import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const TAX_REPORT_ROUTES = [
  { method: 'post', path: '/tax/reports', action: 'TAX_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'type', pattern: PATTERNS.TAX_TYPE, required: true },
    { name: 'period', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    ACTOR,
  ] },
  { method: 'get', path: '/tax/reports', action: 'TAX_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.TAX_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/tax/reports/:id', action: 'TAX_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/tax/reports/:id/file', action: 'TAX_FILE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/tax/reports/:id/pay', action: 'TAX_PAY', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/tax/summary', action: 'TAX_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
