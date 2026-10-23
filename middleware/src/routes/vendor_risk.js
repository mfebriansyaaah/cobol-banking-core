import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const VENDOR_RISK_ROUTES = [
  { method: 'post', path: '/vendors/:code/risk', action: 'VRK_ASSESS', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'level', pattern: PATTERNS.ALT_SEVERITY, required: true },
    { name: 'score', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/vendors/risks', action: 'VRK_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/vendors/risk-summary', action: 'VRK_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
