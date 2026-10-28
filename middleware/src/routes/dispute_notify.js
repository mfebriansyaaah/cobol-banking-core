import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const DISPUTE_NOTIFY_ROUTES = [
  { method: 'post', path: '/disputes/notifications/templates', action: 'DSN_TEMPLATE_SET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'purpose', pattern: PATTERNS.DSN_PURPOSE, required: true },
    { name: 'channel', pattern: PATTERNS.DSN_CHANNEL, required: true },
    { name: 'subject', pattern: PATTERNS.NTF_TEXT, required: true },
    { name: 'body', pattern: PATTERNS.NTF_TEXT, required: true },
    ACTOR,
  ] },
  { method: 'get', path: '/disputes/notifications/templates', action: 'DSN_TEMPLATE_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/disputes/notifications', action: 'DSN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'state', pattern: PATTERNS.DSN_STATE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    { name: 'caseId', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/disputes/notifications/summary', action: 'DSN_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/disputes/notifications/templates/:code', action: 'DSN_TEMPLATE_GET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'delete', path: '/disputes/notifications/templates/:code', action: 'DSN_TEMPLATE_DELETE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/disputes/:id/notifications', action: 'DSN_ENQUEUE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'purpose', pattern: PATTERNS.DSN_PURPOSE, required: true },
    { name: 'recipient', pattern: PATTERNS.EMAIL, required: false },
    { name: 'template', pattern: PATTERNS.RPT_CODE, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/disputes/notifications/:id', action: 'DSN_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/disputes/notifications/:id/retry', action: 'DSN_RETRY', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
];
