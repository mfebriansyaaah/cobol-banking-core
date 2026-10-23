import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const AUDIT_RETENTION_ROUTES = [
  { method: 'post', path: '/audit-retention-policies', action: 'ARE_DEFINE', tokenIdentity: 'actor', fields: [
    { name: 'name', pattern: PATTERNS.KEY, required: true },
    { name: 'days', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit-retention-policies', action: 'ARE_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit-retention-policies/:id', action: 'ARE_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/audit-retention-runs', action: 'ARE_RUN', tokenIdentity: 'actor', fields: [
    { name: 'policyId', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit-retention/summary', action: 'ARE_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
