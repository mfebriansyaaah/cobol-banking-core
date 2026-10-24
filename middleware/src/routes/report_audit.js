import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const REPORT_AUDIT_ROUTES = [
  { method: 'post', path: '/report-audit', action: 'RAU_RECORD', tokenIdentity: 'actor', fields: [
    { name: 'report', pattern: PATTERNS.BATCH_NAME, required: true },
    { name: 'duration', pattern: PATTERNS.INT, required: true },
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/report-audit', action: 'RAU_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/report-audit/:id', action: 'RAU_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/report-audit/summary', action: 'RAU_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
