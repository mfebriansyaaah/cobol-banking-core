import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const ONCALL_DELIVERY_ROUTES = [
  { method: 'post', path: '/oncall/deliveries', action: 'ODL_ENQUEUE', tokenIdentity: 'actor', fields: [
    { name: 'page', pattern: PATTERNS.INT, required: true },
    { name: 'channel', pattern: PATTERNS.ODL_CHANNEL, required: true },
    { name: 'target', pattern: PATTERNS.EMAIL, required: true },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/oncall/deliveries/:id/send', action: 'ODL_SEND', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/oncall/deliveries/:id/retry', action: 'ODL_RETRY', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/oncall/deliveries/:id/confirm', action: 'ODL_CONFIRM', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/oncall/deliveries', action: 'ODL_LIST', tokenIdentity: 'actor', fields: [
    { name: 'page', pattern: PATTERNS.INT, required: false },
    { name: 'status', pattern: PATTERNS.ODL_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/oncall/deliveries/:id', action: 'ODL_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/oncall/deliveries/cleanup', action: 'ODL_CLEANUP', tokenIdentity: 'actor', fields: [
    { name: 'asOf', pattern: PATTERNS.DATE, required: false },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/oncall/delivery-stats', action: 'ODL_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
