import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const RETENTION_JOB_ROUTES = [
  { method: 'post', path: '/retention-policies', action: 'RTJ_POLICY_SET', tokenIdentity: 'actor', fields: [
    { name: 'dataClass', pattern: PATTERNS.RTJ_CLASS, required: true },
    { name: 'days', pattern: PATTERNS.RTJ_DAYS, required: true },
    { name: 'enabled', pattern: PATTERNS.FLAG, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/retention-policies', action: 'RTJ_POLICY_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/retention-policies/:dataClass', action: 'RTJ_POLICY_GET', tokenIdentity: 'actor', fields: [
    { name: 'dataClass', pattern: PATTERNS.RTJ_CLASS, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/retention-runs', action: 'RTJ_RUN', tokenIdentity: 'actor', fields: [
    { name: 'dataClass', pattern: PATTERNS.RTJ_CLASS, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/retention-runs', action: 'RTJ_RUN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/retention-runs/:id', action: 'RTJ_RUN_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/retention-runs/summary', action: 'RTJ_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
