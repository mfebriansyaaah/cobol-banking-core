import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const POLICY_ATTESTATION_ROUTES = [
  { method: 'post', path: '/policy/attestations', action: 'PAT_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'name', pattern: PATTERNS.RPT_NAME, required: true },
    { name: 'owner', pattern: PATTERNS.EMAIL, required: true },
    { name: 'due', pattern: PATTERNS.DATE, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/policy/attestations/:code/attest', action: 'PAT_ATTEST', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/policy/attestations', action: 'PAT_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/policy/attestation-summary', action: 'PAT_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
