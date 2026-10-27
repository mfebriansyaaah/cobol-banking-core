import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const CLT_ROUTES = [
  { method: 'post', path: '/collateral/validate', action: 'CLT_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/collateral/summary', action: 'CLT_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/collateral/audit', action: 'CLT_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/collateral', action: 'CLT_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/collateral', action: 'CLT_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'CLTRef', pattern: PATTERNS.KEY, required: true },
    { name: 'CLTName', pattern: PATTERNS.NAME, required: true },
    { name: 'CLTType', pattern: PATTERNS.NAME, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/collateral/:id', action: 'CLT_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/collateral/:id/calc', action: 'CLT_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/collateral/:id/update', action: 'CLT_UPDATE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'CLTName', pattern: PATTERNS.NAME, required: false },
    { name: 'CLTType', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/collateral/:id/delete', action: 'CLT_DELETE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
