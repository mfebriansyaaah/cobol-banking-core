import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

// Static paths must precede the parameterised /cards/:id routes so that
// "summary" / "audit" / "validate" are not parsed as an id.
export const CARD_ROUTES = [
  { method: 'post', path: '/cards', action: 'CARD_ISSUE', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'type', pattern: PATTERNS.CARD_TYPE, required: true },
    { name: 'limit', pattern: PATTERNS.AMOUNT, required: false },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    ACTOR,
  ] },
  { method: 'post', path: '/cards/validate', action: 'CARD_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'type', pattern: PATTERNS.CARD_TYPE, required: true },
    { name: 'limit', pattern: PATTERNS.AMOUNT, required: false },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/cards/summary', action: 'CARD_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/cards/audit', action: 'CARD_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'cardId', pattern: PATTERNS.INT, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/cards', action: 'CARD_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CARD_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/cards/:id', action: 'CARD_GET', tokenIdentity: 'actor', fields: [
    ID, BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/cards/:id/statement', action: 'CARD_STATEMENT', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/block', action: 'CARD_BLOCK', tokenIdentity: 'actor', fields: [
    ID, BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/unblock', action: 'CARD_UNBLOCK', tokenIdentity: 'actor', fields: [
    ID, BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/close', action: 'CARD_CLOSE', tokenIdentity: 'actor', fields: [
    ID, BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/authorize', action: 'CARD_AUTHORIZE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'merchant', pattern: PATTERNS.NAME, required: false },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/capture', action: 'CARD_CAPTURE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'authRef', pattern: PATTERNS.KEY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/repay', action: 'CARD_REPAY', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/reverse', action: 'CARD_REVERSE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'authRef', pattern: PATTERNS.KEY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/limit', action: 'CARD_LIMIT_SET', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'limit', pattern: PATTERNS.AMOUNT, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/replace', action: 'CARD_REPLACE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'ref', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
