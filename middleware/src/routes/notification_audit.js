import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const NOTIFICATION_AUDIT_ROUTES = [
  { method: 'post', path: '/notification-audit', action: 'NAU_ENQUEUE', tokenIdentity: 'actor', fields: [
    { name: 'channel', pattern: PATTERNS.NTF_CHANNEL, required: true },
    { name: 'recipient', pattern: PATTERNS.EMAIL, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/notification-audit', action: 'NAU_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.DSN_STATE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/notification-audit/summary', action: 'NAU_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/notification-audit/:id', action: 'NAU_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/notification-audit/:id/retry', action: 'NAU_RETRY', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
];
