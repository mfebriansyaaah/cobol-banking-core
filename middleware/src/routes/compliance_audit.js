import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const COMPLIANCE_AUDIT_ROUTES = [
  { method: 'post', path: '/compliance-findings', action: 'CA_FINDING_RAISE', tokenIdentity: 'actor', fields: [
    { name: 'title', pattern: PATTERNS.BATCH_NAME, required: true },
    { name: 'severity', pattern: PATTERNS.ALT_SEVERITY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance-findings', action: 'CA_FINDING_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.ALT_STATE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance-findings/:id', action: 'CA_FINDING_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/compliance-findings/:id/close', action: 'CA_FINDING_CLOSE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance-findings/summary', action: 'CA_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
