import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const ONCALL_ROUTES = [
  { method: 'post', path: '/oncall/rotations', action: 'ONC_ROTATION_SET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'name', pattern: PATTERNS.RPT_NAME, required: true },
    { name: 'timezone', pattern: PATTERNS.RPT_NAME, required: false },
    { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/oncall/rotations', action: 'ONC_ROTATION_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/oncall/rotations/:code/shifts', action: 'ONC_SHIFT_ADD', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'user', pattern: PATTERNS.EMAIL, required: true },
    { name: 'window', pattern: PATTERNS.ONC_SHIFT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/oncall/rotations/:code/shifts', action: 'ONC_SHIFT_LIST', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/oncall/rotations/:code/current', action: 'ONC_CURRENT', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'asOf', pattern: PATTERNS.ONC_DATETIME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/oncall/policies', action: 'ONC_POLICY_SET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'alertType', pattern: PATTERNS.ALT_TYPE, required: true },
    { name: 'severity', pattern: PATTERNS.ALT_SEVERITY, required: true },
    { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/oncall/policies', action: 'ONC_POLICY_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/oncall/policies/:code/steps', action: 'ONC_STEP_ADD', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'step', pattern: PATTERNS.ONC_STEP, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/oncall/policies/:code/steps', action: 'ONC_STEP_LIST', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/oncall/pages', action: 'ONC_PAGE_ALERT', tokenIdentity: 'actor', fields: [
    { name: 'alertId', pattern: PATTERNS.INT, required: true },
    { name: 'policy', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/oncall/pages', action: 'ONC_PAGE_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.ONC_PAGE_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/oncall/pages/:id/ack', action: 'ONC_ACK_PAGE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/oncall/pages/:id/resolve', action: 'ONC_RESOLVE_PAGE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
