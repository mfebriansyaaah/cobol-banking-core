import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const CHANGE_CONTROL_ROUTES = [
  { method: 'post', path: '/changes', action: 'CHG_REQUEST', tokenIdentity: 'actor', fields: [
    { name: 'title', pattern: PATTERNS.BATCH_NAME, required: true },
    { name: 'type', pattern: PATTERNS.BATCH_DETAIL, required: true },
    { name: 'risk', pattern: PATTERNS.ALT_SEVERITY, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/changes', action: 'CHG_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/changes/summary', action: 'CHG_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/changes/:id', action: 'CHG_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/changes/:id/approve', action: 'CHG_APPROVE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/changes/:id/reject', action: 'CHG_REJECT', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/changes/:id/deploy', action: 'CHG_DEPLOY', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/changes/:id/rollback', action: 'CHG_ROLLBACK', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
];
