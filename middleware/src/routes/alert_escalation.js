import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const ALERT_ESCALATION_ROUTES = [
  { method: 'post', path: '/alerts/escalation/policies', action: 'ALE_POLICY_SET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'alertType', pattern: PATTERNS.ALT_TYPE, required: true },
    { name: 'severity', pattern: PATTERNS.ALE_SEVERITY, required: true },
    { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/alerts/escalation/policies', action: 'ALE_POLICY_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/alerts/escalation/policies/:code/steps', action: 'ALE_STEP_ADD', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'step', pattern: PATTERNS.ALE_STEP, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/alerts/escalation/policies/:code/steps', action: 'ALE_STEP_LIST', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/alerts/:id/escalate', action: 'ALE_ESCALATE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'policy', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/alerts/escalations', action: 'ALE_RUN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.ALE_RUN_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/alerts/escalations/:id', action: 'ALE_RUN_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/alerts/escalations/:id/ack', action: 'ALE_ACK_RUN', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/alerts/escalations/:id/resolve', action: 'ALE_RESOLVE_RUN', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/alerts/escalation/summary', action: 'ALE_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
