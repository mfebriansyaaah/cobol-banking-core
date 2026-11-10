import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

// Static paths must be declared before the parameterised /deposits/:id ones,
// otherwise "summary" / "audit" are parsed as an id and fail the INT pattern.
export const DEPOSIT_ROUTES = [
  { method: 'post', path: '/deposits', action: 'DEP_OPEN', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'principal', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    { name: 'term', pattern: PATTERNS.TERM, required: true },
    { name: 'rate', pattern: PATTERNS.RATE, required: false },
    ACTOR,
  ] },
  { method: 'get', path: '/deposits', action: 'DEP_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.DEP_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/deposits/mature', action: 'DEP_MATURE', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/deposits/validate', action: 'DEP_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'principal', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    { name: 'term', pattern: PATTERNS.TERM, required: true },
    { name: 'rate', pattern: PATTERNS.RATE, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/deposits/calc', action: 'DEP_CALC', tokenIdentity: 'actor', fields: [
    { name: 'principal', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'rate', pattern: PATTERNS.RATE, required: true },
    { name: 'days', pattern: PATTERNS.TERM, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/deposits/summary', action: 'DEP_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/deposits/audit', action: 'DEP_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'depositId', pattern: PATTERNS.INT, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/deposits/:id', action: 'DEP_GET', tokenIdentity: 'actor', fields: [
    ID, BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/deposits/:id/close', action: 'DEP_CLOSE', tokenIdentity: 'actor', fields: [
    ID, BLANK, BLANK, BLANK,
    { name: 'idempotencyKey', pattern: PATTERNS.KEY, required: false },
    ACTOR,
  ] },
  { method: 'post', path: '/deposits/:id/accrue', action: 'DEP_ACCRUE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'days', pattern: PATTERNS.TERM, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/deposits/:id/post', action: 'DEP_POST', tokenIdentity: 'actor', fields: [
    ID, BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/deposits/:id/settle', action: 'DEP_SETTLE', tokenIdentity: 'actor', fields: [
    ID, BLANK, BLANK, BLANK,
    { name: 'idempotencyKey', pattern: PATTERNS.KEY, required: false },
    ACTOR,
  ] },
  { method: 'get', path: '/deposits/:id/statement', action: 'DEP_STATEMENT', tokenIdentity: 'actor', fields: [
    ID, BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
];
