import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const EXPORT_STREAM_ROUTES = [
  { method: 'post', path: '/exports/:id/download-token', action: 'XST_TOKEN_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'ttl', pattern: PATTERNS.XST_TTL, required: true },
    { name: 'max', pattern: PATTERNS.XST_LEN, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/exports/download-tokens', action: 'XST_TOKEN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    { name: 'archive', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/exports/download-tokens/:token', action: 'XST_TOKEN_GET', tokenIdentity: 'actor', fields: [
    { name: 'token', pattern: PATTERNS.KEY, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'delete', path: '/exports/download-tokens/:token', action: 'XST_TOKEN_REVOKE', tokenIdentity: 'actor', fields: [
    { name: 'token', pattern: PATTERNS.KEY, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/exports/download-tokens/:token/chunk', action: 'XST_CHUNK', tokenIdentity: 'actor', fields: [
    { name: 'token', pattern: PATTERNS.KEY, required: true },
    { name: 'offset', pattern: PATTERNS.XST_OFFSET, required: false },
    { name: 'length', pattern: PATTERNS.XST_LEN, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/exports/download-tokens/:token/verify', action: 'XST_VERIFY', tokenIdentity: 'actor', fields: [
    { name: 'token', pattern: PATTERNS.KEY, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/exports/download-tokens/cleanup', action: 'XST_CLEANUP', tokenIdentity: 'actor', fields: [
    { name: 'asOf', pattern: PATTERNS.DATE, required: false },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/exports/download-stats', action: 'XST_STATS', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
