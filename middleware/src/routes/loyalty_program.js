import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const LYP_ROUTES = [
  // DEPRECATED: stateless amount check; earn preview is POST /loyalty/validate (program rate).
  { method: 'post', path: '/loyalty-programs/validate', action: 'LYP_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/loyalty-programs/summary', action: 'LYP_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/loyalty-programs/audit', action: 'LYP_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/loyalty-programs', action: 'LYP_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'programType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/loyalty-programs', action: 'LYP_CREATE', tokenIdentity: 'actor', fields: [ { name: 'loyaltyRef', pattern: PATTERNS.KEY, required: true }, { name: 'programName', pattern: PATTERNS.NAME, required: true }, { name: 'programType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/loyalty-programs/:id', action: 'LYP_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  // DEPRECATED: generic +1 calc; use POST /loyalty/earn (idempotent source + rate).
  { method: 'post', path: '/loyalty-programs/:id/calc', action: 'LYP_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  // DEPRECATED: generic metadata update; program lifecycle via /loyalty/programs + :id/activate.
  { method: 'post', path: '/loyalty-programs/:id/update', action: 'LYP_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'programName', pattern: PATTERNS.NAME, required: false }, { name: 'programType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  // DEPRECATED: generic close; redemptions use POST /loyalty/redeem (balance-guarded).
  { method: 'post', path: '/loyalty-programs/:id/delete', action: 'LYP_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
