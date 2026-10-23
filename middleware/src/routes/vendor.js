import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const VENDOR_ROUTES = [
  { method: 'post', path: '/vendors', action: 'VND_VENDOR_SET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'name', pattern: PATTERNS.RPT_NAME, required: true },
    { name: 'status', pattern: PATTERNS.VND_STATUS, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/vendors', action: 'VND_VENDOR_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/vendors/:code/retire', action: 'VND_VENDOR_RETIRE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/vendors/summary', action: 'VND_VENDOR_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
