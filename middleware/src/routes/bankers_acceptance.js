import { PATTERNS } from '../validation.js';
// DEPRECATED: generic clone; use /trade-finance/lc. Do not extend.
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const BAC_ROUTES = [
  { method: 'post', path: '/bankers-acceptance/validate', action: 'BAC_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/bankers-acceptance/summary', action: 'BAC_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/bankers-acceptance/audit', action: 'BAC_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/bankers-acceptance', action: 'BAC_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'acceptanceType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/bankers-acceptance', action: 'BAC_CREATE', tokenIdentity: 'actor', fields: [ { name: 'bacRef', pattern: PATTERNS.KEY, required: true }, { name: 'drawerName', pattern: PATTERNS.NAME, required: true }, { name: 'acceptanceType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/bankers-acceptance/:id', action: 'BAC_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/bankers-acceptance/:id/calc', action: 'BAC_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/bankers-acceptance/:id/update', action: 'BAC_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'drawerName', pattern: PATTERNS.NAME, required: false }, { name: 'acceptanceType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/bankers-acceptance/:id/delete', action: 'BAC_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
