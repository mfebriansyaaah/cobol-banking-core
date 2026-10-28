import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const DISASTER_RECOVERY_ROUTES = [
  { method: 'post', path: '/dr-plans', action: 'DCR_DEFINE', tokenIdentity: 'actor', fields: [
    { name: 'name', pattern: PATTERNS.BATCH_NAME, required: true },
    { name: 'rto', pattern: PATTERNS.INT, required: true },
    { name: 'rpo', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/dr-plans', action: 'DCR_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/dr-plans/:id', action: 'DCR_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/dr-plans/:id/test', action: 'DCR_TEST', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'outcome', pattern: PATTERNS.BATCH_DETAIL, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/dr-plans/:id/complete', action: 'DCR_COMPLETE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/dr-plans/summary', action: 'DCR_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
