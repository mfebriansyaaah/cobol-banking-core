import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const LEGAL_HOLD_ROUTES = [
  { method: 'post', path: '/legal-holds', action: 'LHO_PLACE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'caseRef', pattern: PATTERNS.LHO_CASE, required: true },
    { name: 'scope', pattern: PATTERNS.LHO_SCOPE, required: true },
    { name: 'reason', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/legal-holds/:id/release', action: 'LHO_RELEASE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'reason', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/legal-holds', action: 'LHO_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.LHO_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/legal-holds/:id', action: 'LHO_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/legal-holds/check', action: 'LHO_CHECK', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/legal-holds/summary', action: 'LHO_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
