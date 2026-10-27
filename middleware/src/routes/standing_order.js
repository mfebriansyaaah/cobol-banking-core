import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const STO_ROUTES = [
  { method: 'post', path: '/standing-order/validate', action: 'STO_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/standing-order/summary', action: 'STO_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/standing-order/audit', action: 'STO_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/standing-order', action: 'STO_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/standing-order', action: 'STO_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'STORef', pattern: PATTERNS.KEY, required: true },
    { name: 'STOName', pattern: PATTERNS.NAME, required: true },
    { name: 'STOType', pattern: PATTERNS.NAME, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/standing-order/:id', action: 'STO_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/standing-order/:id/calc', action: 'STO_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/standing-order/:id/update', action: 'STO_UPDATE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'STOName', pattern: PATTERNS.NAME, required: false },
    { name: 'STOType', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/standing-order/:id/delete', action: 'STO_DELETE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
