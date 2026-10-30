import { PATTERNS } from '../validation.js';
// DEPRECATED: generic template clone; use /tax/* withholding API (tax_management_core). Kept for backward compat.
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const TXW_ROUTES = [
  { method: 'post', path: '/tax-withholding/validate', action: 'TXW_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/tax-withholding/summary', action: 'TXW_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/tax-withholding/audit', action: 'TXW_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/tax-withholding', action: 'TXW_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'taxwhType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/tax-withholding', action: 'TXW_CREATE', tokenIdentity: 'actor', fields: [ { name: 'taxwhRef', pattern: PATTERNS.KEY, required: true }, { name: 'employeeName', pattern: PATTERNS.NAME, required: true }, { name: 'taxwhType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/tax-withholding/:id', action: 'TXW_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/tax-withholding/:id/calc', action: 'TXW_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/tax-withholding/:id/update', action: 'TXW_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'employeeName', pattern: PATTERNS.NAME, required: false }, { name: 'taxwhType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/tax-withholding/:id/delete', action: 'TXW_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
