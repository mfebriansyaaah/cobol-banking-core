import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const KYC_PERIODIC_ROUTES = [
  { method: 'post', path: '/compliance/kyc/validate', action: 'KCP_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/kyc/summary', action: 'KCP_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/compliance/kyc/audit', action: 'KCP_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/kyc', action: 'KCP_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'email', pattern: PATTERNS.EMAIL, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/compliance/kyc', action: 'KCP_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'reviewRef', pattern: PATTERNS.KEY, required: true },
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'riskScore', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/kyc/:id', action: 'KCP_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/compliance/kyc/:id/submit', action: 'KCP_SUBMIT', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/compliance/kyc/:id/approve', action: 'KCP_APPROVE', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/compliance/kyc/:id/update', action: 'KCP_UPDATE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'customerEmail', pattern: PATTERNS.EMAIL, required: false },
    { name: 'riskScore', pattern: PATTERNS.AMOUNT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/compliance/kyc/:id/close', action: 'KCP_CLOSE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
