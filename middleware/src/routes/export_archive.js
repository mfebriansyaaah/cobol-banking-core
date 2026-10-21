import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const EXPORT_ARCHIVE_ROUTES = [
  {
    method: 'post', path: '/exports/reports/:runId', action: 'EXP_REPORT_SAVE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'runId', pattern: PATTERNS.INT, required: true },
      { name: 'format', pattern: PATTERNS.EXP_FORMAT, required: true },
      { name: 'retention', pattern: PATTERNS.EXP_DAYS, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/exports/imports/:code', action: 'EXP_IMPORT_SAVE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'format', pattern: PATTERNS.EXP_FORMAT, required: true },
      { name: 'retention', pattern: PATTERNS.EXP_DAYS, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/exports/stats', action: 'EXP_STATS',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post', path: '/exports/prune', action: 'EXP_PRUNE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'asOf', pattern: PATTERNS.DATE, required: false },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/exports', action: 'EXP_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'type', pattern: PATTERNS.EXP_TYPE, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/exports/:id', action: 'EXP_GET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/exports/:id/content', action: 'EXP_CONTENT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/exports/:id/verify', action: 'EXP_VERIFY',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/exports/:id/extend', action: 'EXP_EXTEND',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'days', pattern: PATTERNS.EXP_DAYS, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'delete', path: '/exports/:id', action: 'EXP_DELETE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
];
