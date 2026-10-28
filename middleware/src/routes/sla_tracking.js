import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const SLA_TRACKING_ROUTES = [
  { method: 'post', path: '/sla', action: 'SLA_DEFINE', tokenIdentity: 'actor', fields: [
    { name: 'name', pattern: PATTERNS.KEY, required: true },
    { name: 'target', pattern: PATTERNS.AMOUNT, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/sla', action: 'SLA_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/sla/summary', action: 'SLA_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/sla/:id', action: 'SLA_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/sla/:id/breach', action: 'SLA_BREACH', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'observed', pattern: PATTERNS.BATCH_DETAIL, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
