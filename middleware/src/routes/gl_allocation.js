import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const GL_ALLOCATION_ROUTES = [
  { method: 'post', path: '/finance/gl-allocation/validate', action: 'GLA_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/finance/gl-allocation/summary', action: 'GLA_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/finance/gl-allocation/audit', action: 'GLA_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/finance/gl-allocation', action: 'GLA_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.GLA_LIST_STATUS, required: false },
    { name: 'targetGl', pattern: PATTERNS.GL_ACCOUNT, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/finance/gl-allocation', action: 'GLA_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'allocRef', pattern: PATTERNS.KEY, required: true },
    { name: 'sourceRef', pattern: PATTERNS.NAME, required: true },
    { name: 'targetGl', pattern: PATTERNS.GL_ACCOUNT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/finance/gl-allocation/:id', action: 'GLA_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/finance/gl-allocation/:id/allocate', action: 'GLA_ALLO', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/finance/gl-allocation/:id/close', action: 'GLA_CLOSE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
