import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const KYC_REVIEW_ROUTES = [
  { method: 'post', path: '/kyc/reviews', action: 'KYC_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'type', pattern: PATTERNS.KYC_TYPE, required: true },
    { name: 'risk', pattern: PATTERNS.KYC_RISK, required: true },
    { name: 'due', pattern: PATTERNS.DATE, required: false },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    ACTOR,
  ] },
  { method: 'get', path: '/kyc/reviews', action: 'KYC_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.KYC_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/kyc/reviews/:id', action: 'KYC_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/kyc/reviews/:id/approve', action: 'KYC_APPROVE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/kyc/reviews/:id/reject', action: 'KYC_REJECT', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/kyc/reviews/:id/escalate', action: 'KYC_ESCALATE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/kyc/summary', action: 'KYC_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
