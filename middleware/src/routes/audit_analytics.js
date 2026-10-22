import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const AUDIT_ANALYTICS_ROUTES = [
  { method: 'get', path: '/audit/summary', action: 'AAN_SUMMARY', tokenIdentity: 'actor', fields: [
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    { name: 'actor', pattern: PATTERNS.EMAIL, required: false },
    { name: 'entity', pattern: PATTERNS.BATCH_NAME, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/actions', action: 'AAN_ACTIONS', tokenIdentity: 'actor', fields: [
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/actors', action: 'AAN_ACTORS', tokenIdentity: 'actor', fields: [
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/entities', action: 'AAN_ENTITIES', tokenIdentity: 'actor', fields: [
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/trend', action: 'AAN_TREND', tokenIdentity: 'actor', fields: [
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    { name: 'actor', pattern: PATTERNS.EMAIL, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/failures', action: 'AAN_FAILURES', tokenIdentity: 'actor', fields: [
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/actors/:email', action: 'AAN_ACTOR_DETAIL', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/anomalies', action: 'AAN_ANOMALY', tokenIdentity: 'actor', fields: [
    { name: 'threshold', pattern: PATTERNS.INT, required: false },
    { name: 'windowHours', pattern: PATTERNS.INT, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/audit/retention', action: 'AAN_RETENTION', tokenIdentity: 'actor', fields: [
    { name: 'cutoff', pattern: PATTERNS.DATE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/audit/snapshot', action: 'AAN_SNAPSHOT', tokenIdentity: 'actor', fields: [
    { name: 'date', pattern: PATTERNS.DATE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/search', action: 'AAN_SEARCH', tokenIdentity: 'actor', fields: [
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    { name: 'action', pattern: PATTERNS.AUDIT_ACTION, required: false },
    ACTOR,
  ] },
];
