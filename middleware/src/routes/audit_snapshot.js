import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const AUDIT_SNAPSHOT_ROUTES = [
  { method: 'post', path: '/audit/snapshots', action: 'ASN_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'from', pattern: PATTERNS.DATE, required: true },
    { name: 'to', pattern: PATTERNS.DATE, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/snapshots', action: 'ASN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/snapshots/:code', action: 'ASN_GET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/snapshots/:code/verify', action: 'ASN_VERIFY', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/audit/snapshot-summary', action: 'ASN_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
