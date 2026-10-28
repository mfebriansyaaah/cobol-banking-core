import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const ACCESS_AUDIT_ROUTES = [
  { method: 'post', path: '/access-audit', action: 'AAU_RECORD', tokenIdentity: 'actor', fields: [
    { name: 'event', pattern: PATTERNS.AUDIT_ACTION, required: true },
    { name: 'subject', pattern: PATTERNS.EMAIL, required: false },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/access-audit', action: 'AAU_LIST', tokenIdentity: 'actor', fields: [
    { name: 'event', pattern: PATTERNS.AUDIT_ACTION, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/access-audit/summary', action: 'AAU_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/access-audit/:id', action: 'AAU_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
];
