import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const SLO_REPORT_ROUTES = [
  { method: 'post', path: '/slo', action: 'SLO_DEFINE', tokenIdentity: 'actor', fields: [
    { name: 'name', pattern: PATTERNS.KEY, required: true },
    { name: 'target', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'windowDays', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/slo', action: 'SLO_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/slo/summary', action: 'SLO_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/slo/:name', action: 'SLO_GET', tokenIdentity: 'actor', fields: [
    { name: 'name', pattern: PATTERNS.KEY, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/slo/:name/record', action: 'SLO_RECORD', tokenIdentity: 'actor', fields: [
    { name: 'name', pattern: PATTERNS.KEY, required: true },
    { name: 'good', pattern: PATTERNS.INT, required: true },
    { name: 'total', pattern: PATTERNS.INT, required: true },
    { name: 'windowStart', pattern: PATTERNS.DATE, required: false },
    { name: 'windowEnd', pattern: PATTERNS.DATE, required: false },
    ACTOR,
  ] },
  { method: 'get', path: '/slo/:name/burn', action: 'SLO_BURN', tokenIdentity: 'actor', fields: [
    { name: 'name', pattern: PATTERNS.KEY, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
];
