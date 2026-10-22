import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const SETTLEMENT_RECON_ROUTES = [
  { method: 'post', path: '/settlement/runs', action: 'STR_RUN_START', tokenIdentity: 'actor', fields: [
    { name: 'batch', pattern: PATTERNS.BATCH_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/settlement/runs/:id/items', action: 'STR_ITEM_ADD', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'ref', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'status', pattern: PATTERNS.STR_STATUS, required: true },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    ACTOR,
  ] },
  { method: 'post', path: '/settlement/runs/:id/complete', action: 'STR_RUN_COMPLETE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'matched', pattern: PATTERNS.BATCH_COUNT, required: true },
    { name: 'broken', pattern: PATTERNS.BATCH_COUNT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/settlement/runs', action: 'STR_RUN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.BATCH_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/settlement/runs/:id', action: 'STR_RUN_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/settlement/runs/:id/items', action: 'STR_ITEM_LIST', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/settlement/items/:id/resolve', action: 'STR_ITEM_RESOLVE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/settlement/summary', action: 'STR_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
