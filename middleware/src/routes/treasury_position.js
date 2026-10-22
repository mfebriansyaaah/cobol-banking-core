import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const TREASURY_POSITION_ROUTES = [
  { method: 'post', path: '/treasury/positions', action: 'TRP_OPEN', tokenIdentity: 'actor', fields: [
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'asOf', pattern: PATTERNS.DATE, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/treasury/positions/:id/close', action: 'TRP_CLOSE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/treasury/positions', action: 'TRP_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.TRP_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/treasury/summary', action: 'TRP_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
