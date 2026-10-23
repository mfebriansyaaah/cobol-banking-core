import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const BACKUP_RESTORE_ROUTES = [
  { method: 'post', path: '/backups', action: 'BKP_START', tokenIdentity: 'actor', fields: [
    { name: 'type', pattern: PATTERNS.BATCH_TYPE, required: true },
    { name: 'target', pattern: PATTERNS.BATCH_NAME, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/backups', action: 'BKP_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.REQUEST_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/backups/:id', action: 'BKP_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/backups/:id/verify', action: 'BKP_VERIFY', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/backups/:id/restore', action: 'BKP_RESTORE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/backups/summary', action: 'BKP_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
