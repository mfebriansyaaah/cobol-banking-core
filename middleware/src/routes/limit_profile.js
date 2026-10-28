import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const LIMIT_PROFILE_ROUTES = [
  { method: 'post', path: '/limit-profiles', action: 'LPR_SET', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'daily', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'monthly', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'tier', pattern: PATTERNS.LPR_TIER, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/limit-profiles', action: 'LPR_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/limit-profiles/summary', action: 'LPR_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/limit-profiles/:email', action: 'LPR_GET', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
];
