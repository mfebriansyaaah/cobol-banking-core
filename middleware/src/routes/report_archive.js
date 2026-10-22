import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const REPORT_ARCHIVE_ROUTES = [
  { method: 'post', path: '/reports/archives', action: 'RPA_ARCHIVE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'type', pattern: PATTERNS.RSC_REPORT, required: true },
    { name: 'period', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'rows', pattern: PATTERNS.BATCH_COUNT, required: false },
    { name: 'checksum', pattern: PATTERNS.RPT_CHECKSUM, required: false },
    ACTOR,
  ] },
  { method: 'get', path: '/reports/archives', action: 'RPA_LIST', tokenIdentity: 'actor', fields: [
    { name: 'type', pattern: PATTERNS.RSC_REPORT, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/reports/archives/:code', action: 'RPA_GET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/reports/archives/purge', action: 'RPA_PURGE', tokenIdentity: 'actor', fields: [
    { name: 'asOf', pattern: PATTERNS.DATE, required: false },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/reports/archive-summary', action: 'RPA_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
