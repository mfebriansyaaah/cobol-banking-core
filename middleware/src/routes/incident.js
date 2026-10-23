import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const INCIDENT_ROUTES = [
  { method: 'post', path: '/incidents', action: 'INC_RAISE', tokenIdentity: 'actor', fields: [
    { name: 'title', pattern: PATTERNS.BATCH_NAME, required: true },
    { name: 'severity', pattern: PATTERNS.ALT_SEVERITY, required: true },
    { name: 'source', pattern: PATTERNS.BATCH_DETAIL, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/incidents', action: 'INC_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.ALT_STATE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/incidents/:id', action: 'INC_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/incidents/:id/assign', action: 'INC_ASSIGN', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'assignee', pattern: PATTERNS.EMAIL, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/incidents/:id/ack', action: 'INC_ACK', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/incidents/:id/resolve', action: 'INC_RESOLVE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'resolution', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/incidents/:id/close', action: 'INC_CLOSE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/incidents/summary', action: 'INC_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
