import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const REGULATORY_REPORT_ROUTES = [
  { method: 'post', path: '/regulatory/reports', action: 'REG_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'regulator', pattern: PATTERNS.REG_REGULATOR, required: true },
    { name: 'type', pattern: PATTERNS.REG_TYPE, required: true },
    { name: 'period', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'rows', pattern: PATTERNS.BATCH_COUNT, required: false },
    ACTOR,
  ] },
  { method: 'get', path: '/regulatory/reports', action: 'REG_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.REG_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/regulatory/reports/:code', action: 'REG_GET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/regulatory/reports/:code/submit', action: 'REG_SUBMIT', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/regulatory/reports/:code/accept', action: 'REG_ACCEPT', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/regulatory/reports/:code/reject', action: 'REG_REJECT', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/regulatory/summary', action: 'REG_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
