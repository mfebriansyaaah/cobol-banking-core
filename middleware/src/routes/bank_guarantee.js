import { PATTERNS } from '../validation.js';
// DEPRECATED: generic BKG_* routes; use /trade-finance/bg (BKG_* domain lifecycle). Kept for backward compat.
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const BKG_ROUTES = [
  { method: 'post', path: '/bank-guarantees/validate', action: 'BKG_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/bank-guarantees/summary', action: 'BKG_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/bank-guarantees/audit', action: 'BKG_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/bank-guarantees', action: 'BKG_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'guaranteeType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/bank-guarantees', action: 'BKG_CREATE', tokenIdentity: 'actor', fields: [ { name: 'guaranteeRef', pattern: PATTERNS.KEY, required: true }, { name: 'beneficiaryName', pattern: PATTERNS.NAME, required: true }, { name: 'guaranteeType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/bank-guarantees/:id', action: 'BKG_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/bank-guarantees/:id/calc', action: 'BKG_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/bank-guarantees/:id/update', action: 'BKG_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'beneficiaryName', pattern: PATTERNS.NAME, required: false }, { name: 'guaranteeType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/bank-guarantees/:id/delete', action: 'BKG_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
