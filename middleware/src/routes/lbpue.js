import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const LBPUE_ROUTES = [
  { method: 'post', path: '/lbpue/reports', action: 'LBP_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'period', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'rows', pattern: PATTERNS.BATCH_COUNT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/lbpue/reports', action: 'LBP_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.LBP_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/lbpue/reports/:code', action: 'LBP_GET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/lbpue/reports/:code/submit', action: 'LBP_SUBMIT', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/lbpue/summary', action: 'LBP_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
