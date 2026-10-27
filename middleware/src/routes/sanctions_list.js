import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const SANCTIONS_LIST_ROUTES = [
  { method: 'post', path: '/compliance/sanctions/validate', action: 'SCL_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/sanctions/summary', action: 'SCL_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/compliance/sanctions/audit', action: 'SCL_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/sanctions', action: 'SCL_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/compliance/sanctions', action: 'SCL_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'listRef', pattern: PATTERNS.KEY, required: true },
    { name: 'entityName', pattern: PATTERNS.NAME, required: true },
    { name: 'listType', pattern: PATTERNS.NAME, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/sanctions/:id', action: 'SCL_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/compliance/sanctions/:id/check', action: 'SCL_SCREEN', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/compliance/sanctions/:id/update', action: 'SCL_UPDATE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'entityName', pattern: PATTERNS.NAME, required: false },
    { name: 'listType', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/compliance/sanctions/:id/close', action: 'SCL_CLOSE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
