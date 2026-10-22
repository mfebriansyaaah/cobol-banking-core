import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const RECON_EXCEPTION_ROUTES = [
  { method: 'post', path: '/recon/exceptions', action: 'REX_OPEN', tokenIdentity: 'actor', fields: [
    { name: 'findingId', pattern: PATTERNS.INT, required: false },
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'priority', pattern: PATTERNS.REX_PRIORITY, required: true },
    { name: 'owner', pattern: PATTERNS.EMAIL, required: false },
    { name: 'due', pattern: PATTERNS.DATE, required: false },
    ACTOR,
  ] },
  { method: 'get', path: '/recon/exceptions/summary', action: 'REX_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/recon/exceptions/overdue', action: 'REX_OVERDUE', tokenIdentity: 'actor', fields: [
    { name: 'asOf', pattern: PATTERNS.DATE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/recon/exceptions', action: 'REX_LIST', tokenIdentity: 'actor', fields: [
    { name: 'state', pattern: PATTERNS.REX_STATE, required: false },
    { name: 'priority', pattern: PATTERNS.REX_PRIORITY, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    { name: 'owner', pattern: PATTERNS.EMAIL, required: false },
    ACTOR,
  ] },
  { method: 'get', path: '/recon/exceptions/:id', action: 'REX_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/recon/exceptions/:id/assign', action: 'REX_ASSIGN', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'owner', pattern: PATTERNS.EMAIL, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/recon/exceptions/:id/notes', action: 'REX_NOTE_ADD', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/recon/exceptions/:id/resolve', action: 'REX_RESOLVE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'resolution', pattern: PATTERNS.BATCH_DETAIL, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/recon/exceptions/:id/reject', action: 'REX_REJECT', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'reason', pattern: PATTERNS.BATCH_DETAIL, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/recon/exceptions/:id/escalate', action: 'REX_ESCALATE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'manager', pattern: PATTERNS.EMAIL, required: true },
    { name: 'reason', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/recon/exceptions/:id/close', action: 'REX_CLOSE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/recon/exceptions/:id/history', action: 'REX_HISTORY', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
];
