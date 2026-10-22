import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const REGULATORY_CALENDAR_ROUTES = [
  { method: 'post', path: '/regulatory/calendar', action: 'RCL_EVENT_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'title', pattern: PATTERNS.RPT_NAME, required: true },
    { name: 'regulator', pattern: PATTERNS.RCL_REGULATOR, required: true },
    { name: 'due', pattern: PATTERNS.DATE, required: true },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/regulatory/calendar', action: 'RCL_EVENT_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.RCL_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/regulatory/calendar/:code/done', action: 'RCL_EVENT_DONE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/regulatory/calendar-summary', action: 'RCL_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
