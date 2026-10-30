import { PATTERNS } from '../validation.js';
// DEPRECATED: generic clone; use /trade-finance/lc. Do not extend.
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const DCRD_ROUTES = [
  { method: 'post', path: '/documentary-credits/validate', action: 'DCRD_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/documentary-credits/summary', action: 'DCRD_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/documentary-credits/audit', action: 'DCRD_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/documentary-credits', action: 'DCRD_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'documentaryCreditType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/documentary-credits', action: 'DCRD_CREATE', tokenIdentity: 'actor', fields: [ { name: 'dcrdRef', pattern: PATTERNS.KEY, required: true }, { name: 'applicantName', pattern: PATTERNS.NAME, required: true }, { name: 'documentaryCreditType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/documentary-credits/:id', action: 'DCRD_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/documentary-credits/:id/calc', action: 'DCRD_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/documentary-credits/:id/update', action: 'DCRD_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'applicantName', pattern: PATTERNS.NAME, required: false }, { name: 'documentaryCreditType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/documentary-credits/:id/delete', action: 'DCRD_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
