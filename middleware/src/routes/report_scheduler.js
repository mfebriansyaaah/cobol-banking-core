import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const REPORT_SCHEDULER_ROUTES = [
  { method: 'post', path: '/reports/schedules', action: 'RSC_SCHEDULE_SET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'report', pattern: PATTERNS.RSC_REPORT, required: true },
    { name: 'frequency', pattern: PATTERNS.RSC_FREQ, required: true },
    { name: 'nextRun', pattern: PATTERNS.DATE, required: true },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/reports/schedules', action: 'RSC_SCHEDULE_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/reports/schedules/:code', action: 'RSC_SCHEDULE_GET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'delete', path: '/reports/schedules/:code', action: 'RSC_SCHEDULE_DELETE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/reports/schedules/:code/runs', action: 'RSC_RUN_START', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/reports/runs/:id/complete', action: 'RSC_RUN_COMPLETE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'rows', pattern: PATTERNS.BATCH_COUNT, required: true },
    { name: 'error', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/reports/schedules/:code/runs', action: 'RSC_RUN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/reports/schedule-summary', action: 'RSC_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
