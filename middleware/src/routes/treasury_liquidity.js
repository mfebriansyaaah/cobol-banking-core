import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const TREASURY_LIQUIDITY_ROUTES = [
  { method: 'post', path: '/treasury/liquidity/validate', action: 'TRL_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/treasury/liquidity/summary', action: 'TRL_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/treasury/liquidity/audit', action: 'TRL_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/treasury/liquidity', action: 'TRL_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.TRL_LIST_STATUS, required: false },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/treasury/liquidity', action: 'TRL_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'liqRef', pattern: PATTERNS.KEY, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    { name: 'sourceRef', pattern: PATTERNS.KEY, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/treasury/liquidity/:id', action: 'TRL_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/treasury/liquidity/:id/post', action: 'TRL_POST', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/treasury/liquidity/:id/settle', action: 'TRL_SETTLE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/treasury/liquidity/:id/close', action: 'TRL_CLOSE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
