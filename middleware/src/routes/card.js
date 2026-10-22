import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const CARD_ROUTES = [
  { method: 'post', path: '/cards', action: 'CARD_ISSUE', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'type', pattern: PATTERNS.CARD_TYPE, required: true },
    { name: 'limit', pattern: PATTERNS.AMOUNT, required: false },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/block', action: 'CARD_BLOCK', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/unblock', action: 'CARD_UNBLOCK', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/cards/:id/close', action: 'CARD_CLOSE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/cards', action: 'CARD_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CARD_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/cards/:id', action: 'CARD_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/cards/summary', action: 'CARD_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
