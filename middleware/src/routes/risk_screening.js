import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const RISK_SCREENING_ROUTES = [
  { method: 'post', path: '/risk/profiles', action: 'RSK_PROFILE_SET', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'level', pattern: PATTERNS.KYC_RISK, required: true },
    { name: 'score', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/risk/profiles/:email', action: 'RSK_PROFILE_GET', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/risk/screen', action: 'RSK_SCREEN', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'severity', pattern: PATTERNS.KYC_RISK, required: true },
    { name: 'hitType', pattern: PATTERNS.REF_CODE, required: true },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/risk/hits', action: 'RSK_HIT_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.BATCH_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/risk/summary', action: 'RSK_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
