import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const AUDIT_DRILLDOWN_ROUTES = [
  { method: 'post', path: '/audit/drilldown/queries', action: 'ADR_QUERY_SAVE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'name', pattern: PATTERNS.RPT_NAME, required: true },
    { name: 'filter', pattern: PATTERNS.ADR_FILTER, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/drilldown/queries', action: 'ADR_QUERY_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/drilldown/queries/:code', action: 'ADR_QUERY_GET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'delete', path: '/audit/drilldown/queries/:code', action: 'ADR_QUERY_DELETE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/audit/drilldown/queries/:code/run', action: 'ADR_RUN', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/drilldown/drill', action: 'ADR_DRILL', tokenIdentity: 'actor', fields: [
    { name: 'action', pattern: PATTERNS.AUDIT_ACTION, required: false },
    { name: 'entity', pattern: PATTERNS.BATCH_DETAIL, required: false },
    { name: 'status', pattern: PATTERNS.AAN_STATUS, required: false },
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    ACTOR,
  ] },
  { method: 'get', path: '/audit/drilldown/summary', action: 'ADR_SUMMARY', tokenIdentity: 'actor', fields: [
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/drilldown/pivot', action: 'ADR_PIVOT', tokenIdentity: 'actor', fields: [
    { name: 'from', pattern: PATTERNS.DATE, required: false },
    { name: 'to', pattern: PATTERNS.DATE, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/drilldown/runs', action: 'ADR_RUN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
];
