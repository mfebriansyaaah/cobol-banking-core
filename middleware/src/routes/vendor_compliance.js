import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const VENDOR_COMPLIANCE_ROUTES = [
  { method: 'post', path: '/vendor-compliance', action: 'VCC_ASSESS', tokenIdentity: 'actor', fields: [
    { name: 'vendor', pattern: PATTERNS.KEY, required: true },
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/vendor-compliance', action: 'VCC_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/vendor-compliance/:id', action: 'VCC_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/vendor-compliance/:id/approve', action: 'VCC_APPROVE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/vendor-compliance/summary', action: 'VCC_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
