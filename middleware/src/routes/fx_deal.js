import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const FX_DEAL_ROUTES = [
  { method: 'post', path: '/fx/deals', action: 'FXD_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'pair', pattern: PATTERNS.CURRENCY, required: true },
    { name: 'side', pattern: PATTERNS.FXD_SIDE, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'rate', pattern: PATTERNS.RATE, required: true },
    ACTOR,
  ] },
  { method: 'post', path: '/fx/deals/:id/confirm', action: 'FXD_CONFIRM', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/fx/deals/:id/settle', action: 'FXD_SETTLE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/fx/deals/:id/cancel', action: 'FXD_CANCEL', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/fx/deals', action: 'FXD_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.FXD_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/fx/deals/:id', action: 'FXD_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/fx/summary', action: 'FXD_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
