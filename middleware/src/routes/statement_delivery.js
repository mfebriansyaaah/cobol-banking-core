import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const STATEMENT_DELIVERY_ROUTES = [
  { method: 'post', path: '/statement-deliveries', action: 'STL_ENQUEUE', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'recipient', pattern: PATTERNS.EMAIL, required: true },
    { name: 'channel', pattern: PATTERNS.STL_CHANNEL, required: false },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/statement-deliveries/:id/send', action: 'STL_SEND', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/statement-deliveries/:id/retry', action: 'STL_RETRY', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/statement-deliveries/:id/deliver', action: 'STL_DELIVER', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/statement-deliveries', action: 'STL_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.STL_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/statement-deliveries/:id', action: 'STL_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/statement-deliveries/cleanup', action: 'STL_CLEANUP', tokenIdentity: 'actor', fields: [
    { name: 'asOf', pattern: PATTERNS.DATE, required: false },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/statement-delivery-stats', action: 'STL_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
