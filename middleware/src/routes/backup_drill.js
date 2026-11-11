import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const BACKUP_DRILL_ROUTES = [
  {
    method: 'post',
    path: '/it/backup-drills/validate',
    action: 'BDR_VALIDATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
      { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
      BLANK,
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/it/backup-drills/summary',
    action: 'BDR_SUMMARY',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/it/backup-drills/audit',
    action: 'BDR_AUDIT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/it/backup-drills',
    action: 'BDR_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'status', pattern: PATTERNS.BDR_LIST_STATUS, required: false },
      { name: 'type', pattern: PATTERNS.NAME, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/it/backup-drills',
    action: 'BDR_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'drillRef', pattern: PATTERNS.KEY, required: true },
      { name: 'targetTable', pattern: PATTERNS.NAME, required: true },
      { name: 'backupType', pattern: PATTERNS.NAME, required: true },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/it/backup-drills/:id',
    action: 'BDR_GET',
    tokenIdentity: 'actor',
    fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/it/backup-drills/:id/run',
    action: 'BDR_RUN',
    tokenIdentity: 'actor',
    fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/it/backup-drills/:id/close',
    action: 'BDR_CLOSE',
    tokenIdentity: 'actor',
    fields: [ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR],
  },
];
