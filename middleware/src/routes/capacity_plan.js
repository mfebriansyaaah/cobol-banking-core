import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const CAPACITY_PLAN_ROUTES = [
  { method: 'post', path: '/capacity-plans', action: 'CAP_DEFINE', tokenIdentity: 'actor', fields: [
    { name: 'name', pattern: PATTERNS.BATCH_NAME, required: true },
    { name: 'threshold', pattern: PATTERNS.BATCH_DETAIL, required: true },
    { name: 'unit', pattern: PATTERNS.SYMBOL, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/capacity-plans', action: 'CAP_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/capacity-plans/summary', action: 'CAP_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/capacity-plans/:id', action: 'CAP_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/capacity-plans/:id/breach', action: 'CAP_BREACH', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'observed', pattern: PATTERNS.BATCH_DETAIL, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
