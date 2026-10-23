import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const PIPELINE_ALERT_ROUTES = [
  { method: 'post', path: '/pipeline-alerts', action: 'PAL_RAISE', tokenIdentity: 'actor', fields: [
    { name: 'pipeline', pattern: PATTERNS.BATCH_NAME, required: true },
    { name: 'severity', pattern: PATTERNS.ALT_SEVERITY, required: true },
    { name: 'message', pattern: PATTERNS.BATCH_DETAIL, required: true },
    { name: 'sourceKey', pattern: PATTERNS.KEY, required: true },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/pipeline-alerts', action: 'PAL_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.ALT_STATE, required: false },
    { name: 'severity', pattern: PATTERNS.ALT_SEVERITY, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/pipeline-alerts/:id', action: 'PAL_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/pipeline-alerts/:id/ack', action: 'PAL_ACK', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/pipeline-alerts/:id/resolve', action: 'PAL_RESOLVE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/pipeline-alerts/summary', action: 'PAL_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
