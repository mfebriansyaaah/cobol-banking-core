import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const CSM_ROUTES = [
  { method: 'post', path: '/case-management/validate', action: 'CSM_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/case-management/summary', action: 'CSM_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/case-management/audit', action: 'CSM_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/case-management', action: 'CSM_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/case-management', action: 'CSM_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'CSMRef', pattern: PATTERNS.KEY, required: true },
    { name: 'CSMName', pattern: PATTERNS.NAME, required: true },
    { name: 'CSMType', pattern: PATTERNS.NAME, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/case-management/:id', action: 'CSM_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/case-management/:id/calc', action: 'CSM_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/case-management/:id/update', action: 'CSM_UPDATE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'CSMName', pattern: PATTERNS.NAME, required: false },
    { name: 'CSMType', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/case-management/:id/delete', action: 'CSM_DELETE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
