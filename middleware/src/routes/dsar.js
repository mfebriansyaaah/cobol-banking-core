import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const DSAR_ROUTES = [
  { method: 'post', path: '/dsar', action: 'DSR_RECEIVE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: PATTERNS.EMAIL, required: true },
    { name: 'type', pattern: PATTERNS.DSR_TYPE, required: true },
    { name: 'scope', pattern: PATTERNS.DSR_SCOPE, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/dsar', action: 'DSR_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.DSR_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/dsar/:id', action: 'DSR_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/dsar/:id/start', action: 'DSR_START', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/dsar/:id/fulfill', action: 'DSR_FULFILL', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/dsar/:id/reject', action: 'DSR_REJECT', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'reason', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/dsar/summary', action: 'DSR_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
