import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const TSD_ROUTES = [
  { method: 'post', path: '/treasury-deals/validate', action: 'TSD_VALIDATE', tokenIdentity: 'actor', fields: [ {{ name: 'amount', pattern: PATTERNS.AMOUNT, required: true }}, {{ name: 'currency', pattern: PATTERNS.CURRENCY, required: true }}, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/treasury-deals/summary', action: 'TSD_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/treasury-deals/audit', action: 'TSD_AUDIT', tokenIdentity: 'actor', fields: [ {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/treasury-deals', action: 'TSD_LIST', tokenIdentity: 'actor', fields: [ {{ name: 'status', pattern: PATTERNS.CODE, required: false }}, {{ name: 'dealType', pattern: PATTERNS.NAME, required: false }}, {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, ACTOR ] },
  { method: 'post', path: '/treasury-deals', action: 'TSD_CREATE', tokenIdentity: 'actor', fields: [ {{ name: 'dealRef', pattern: PATTERNS.KEY, required: true }}, {{ name: 'counterparty', pattern: PATTERNS.NAME, required: true }}, {{ name: 'dealType', pattern: PATTERNS.NAME, required: true }}, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/treasury-deals/:id', action: 'TSD_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/treasury-deals/:id/calc', action: 'TSD_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/treasury-deals/:id/update', action: 'TSD_UPDATE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'counterparty', pattern: PATTERNS.NAME, required: false }}, {{ name: 'dealType', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/treasury-deals/:id/delete', action: 'TSD_DELETE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'reason', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, BLANK, ACTOR ] },
];
