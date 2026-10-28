import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const SCF_ROUTES = [
  { method: 'post', path: '/supply-chain-finance/validate', action: 'SCF_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/supply-chain-finance/summary', action: 'SCF_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/supply-chain-finance/audit', action: 'SCF_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/supply-chain-finance', action: 'SCF_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'scfType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/supply-chain-finance', action: 'SCF_CREATE', tokenIdentity: 'actor', fields: [ { name: 'scfRef', pattern: PATTERNS.KEY, required: true }, { name: 'supplierName', pattern: PATTERNS.NAME, required: true }, { name: 'scfType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/supply-chain-finance/:id', action: 'SCF_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/supply-chain-finance/:id/calc', action: 'SCF_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/supply-chain-finance/:id/update', action: 'SCF_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'supplierName', pattern: PATTERNS.NAME, required: false }, { name: 'scfType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/supply-chain-finance/:id/delete', action: 'SCF_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
