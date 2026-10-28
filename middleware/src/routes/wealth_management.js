import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const WLM_ROUTES = [
  { method: 'post', path: '/wealth-management/validate', action: 'WLM_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/wealth-management/summary', action: 'WLM_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/wealth-management/audit', action: 'WLM_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/wealth-management', action: 'WLM_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'wealthType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/wealth-management', action: 'WLM_CREATE', tokenIdentity: 'actor', fields: [ { name: 'wealthRef', pattern: PATTERNS.KEY, required: true }, { name: 'clientName', pattern: PATTERNS.NAME, required: true }, { name: 'wealthType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/wealth-management/:id', action: 'WLM_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/wealth-management/:id/calc', action: 'WLM_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/wealth-management/:id/update', action: 'WLM_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'clientName', pattern: PATTERNS.NAME, required: false }, { name: 'wealthType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/wealth-management/:id/delete', action: 'WLM_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
