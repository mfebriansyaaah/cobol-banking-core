import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const REPORT_ROUTES = [
  {
    method: 'post', path: '/reports/templates', action: 'RPT_TEMPLATE_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
      { name: 'name', pattern: PATTERNS.RPT_NAME, required: true },
      { name: 'type', pattern: PATTERNS.RPT_TYPE, required: true },
      { name: 'format', pattern: PATTERNS.RPT_FORMAT, required: true },
      { name: 'title', pattern: PATTERNS.RPT_NAME, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/templates', action: 'RPT_TEMPLATE_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'type', pattern: PATTERNS.RPT_TYPE, required: false },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: false },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/templates/:code', action: 'RPT_TEMPLATE_GET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
      { name: 'columns', pattern: PATTERNS.FLAG, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reports/templates/:code/columns', action: 'RPT_COLUMN_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
      { name: 'ordinal', pattern: PATTERNS.INT, required: true },
      { name: 'header', pattern: PATTERNS.RPT_NAME, required: true },
      { name: 'source', pattern: PATTERNS.KEY, required: true },
      { name: 'options', pattern: PATTERNS.RPT_COLUMN_OPTIONS, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/templates/:code/columns', action: 'RPT_COLUMN_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reports/runs', action: 'RPT_RUN_START',
    tokenIdentity: 'actor',
    fields: [
      { name: 'template', pattern: PATTERNS.RPT_CODE, required: true },
      { name: 'parameters', pattern: PATTERNS.RPT_PARAMS, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reports/runs/:id/rows', action: 'RPT_RUN_ROW',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'ordinal', pattern: PATTERNS.INT, required: true },
      { name: 'debit', pattern: PATTERNS.AMOUNT, required: true },
      { name: 'credit', pattern: PATTERNS.AMOUNT, required: true },
      { name: 'row', pattern: PATTERNS.RPT_ROW, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/runs/:id', action: 'RPT_RUN_STATUS',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'details', pattern: PATTERNS.FLAG, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reports/runs/:id/complete', action: 'RPT_RUN_COMPLETE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'counts', pattern: PATTERNS.RPT_COUNTS, required: true },
      { name: 'checksum', pattern: PATTERNS.RPT_CHECKSUM, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reports/runs/:id/fail', action: 'RPT_RUN_FAIL',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'errorCode', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/runs', action: 'RPT_RUN_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'status', pattern: PATTERNS.RPT_STATUS, required: false },
      { name: 'template', pattern: PATTERNS.RPT_CODE, required: false },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/runs/:id/export', action: 'RPT_RUN_EXPORT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'format', pattern: PATTERNS.RPT_FORMAT, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
];
