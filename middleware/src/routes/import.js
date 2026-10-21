import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const IMPORT_ROUTES = [
  {
    method: 'post', path: '/imports/batches', action: 'IMP_BATCH_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'source', pattern: PATTERNS.RPT_NAME, required: true },
      { name: 'type', pattern: PATTERNS.IMP_TYPE, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/imports/batches', action: 'IMP_BATCH_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'status', pattern: PATTERNS.IMP_STATUS, required: false },
      { name: 'type', pattern: PATTERNS.IMP_TYPE, required: false },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/imports/batches/:code', action: 'IMP_BATCH_GET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'rows', pattern: PATTERNS.FLAG, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/imports/batches/:code/rows', action: 'IMP_ROW_STAGE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'rowNo', pattern: PATTERNS.INT, required: true },
      { name: 'raw', pattern: PATTERNS.IMP_RAW, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/imports/batches/:code/validate', action: 'IMP_BATCH_VALIDATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/imports/batches/:code/rows/:rowNo', action: 'IMP_ROW_CORRECT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'rowNo', pattern: PATTERNS.INT, required: true },
      { name: 'raw', pattern: PATTERNS.IMP_RAW, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/imports/batches/:code/errors', action: 'IMP_ERROR_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/imports/batches/:code/post', action: 'IMP_BATCH_POST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/imports/batches/:code/fail', action: 'IMP_BATCH_FAIL',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'errorCode', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/imports/batches/:code/export', action: 'IMP_BATCH_EXPORT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'format', pattern: PATTERNS.RPT_FORMAT, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
];
