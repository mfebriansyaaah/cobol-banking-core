import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const BATCH_ROUTES = [
  {
    method: 'post', path: '/batch/jobs', action: 'BATCH_JOB_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'name', pattern: PATTERNS.BATCH_NAME, required: true },
      { name: 'type', pattern: PATTERNS.BATCH_TYPE, required: true },
      { name: 'frequency', pattern: PATTERNS.BATCH_FREQ, required: true },
      { name: 'schedule', pattern: PATTERNS.BATCH_SCHEDULE, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/batch/jobs', action: 'BATCH_JOB_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'type', pattern: PATTERNS.BATCH_TYPE, required: false },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: false },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/batch/jobs/:code', action: 'BATCH_JOB_UPDATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
      { name: 'frequency', pattern: PATTERNS.BATCH_FREQ, required: true },
      { name: 'time', pattern: PATTERNS.BATCH_TIME, required: true },
      { name: 'maxRetries', pattern: PATTERNS.INT, required: true },
      ACTOR,
    ],
  },
  {
    method: 'post', path: '/batch/jobs/:code/steps', action: 'BATCH_STEP_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'stepNo', pattern: PATTERNS.INT, required: true },
      { name: 'stepCode', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'name', pattern: PATTERNS.BATCH_NAME, required: true },
      { name: 'options', pattern: PATTERNS.BATCH_STEP_OPTIONS, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/batch/jobs/:code/steps', action: 'BATCH_STEP_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/batch/runs', action: 'BATCH_RUN_START',
    tokenIdentity: 'actor',
    fields: [
      { name: 'jobCode', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'businessDate', pattern: PATTERNS.DATE, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/batch/runs', action: 'BATCH_RUN_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'status', pattern: PATTERNS.BATCH_STATUS, required: false },
      { name: 'jobCode', pattern: PATTERNS.BATCH_CODE, required: false },
      { name: 'businessDate', pattern: PATTERNS.DATE, required: false },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/batch/runs/:id', action: 'BATCH_RUN_STATUS',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'details', pattern: PATTERNS.FLAG, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/batch/runs/:id/checkpoint', action: 'BATCH_RUN_CHECKPOINT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'key', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'value', pattern: PATTERNS.BATCH_DETAIL, required: false },
      { name: 'processed', pattern: PATTERNS.BATCH_COUNT, required: true },
      { name: 'totals', pattern: PATTERNS.BATCH_TOTALS, required: true },
      ACTOR,
    ],
  },
  {
    method: 'post', path: '/batch/runs/:id/complete', action: 'BATCH_RUN_COMPLETE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'counts', pattern: PATTERNS.BATCH_COUNTS, required: true },
      { name: 'totals', pattern: PATTERNS.BATCH_TOTALS, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/batch/runs/:id/fail', action: 'BATCH_RUN_FAIL',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'errorCode', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/batch/runs/:id/retry', action: 'BATCH_RUN_RETRY',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/batch/runs/:id/steps/:step', action: 'BATCH_RUN_STEP',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'step', pattern: PATTERNS.INT, required: true },
      { name: 'status', pattern: PATTERNS.BATCH_STEP_STATUS, required: true },
      { name: 'counts', pattern: PATTERNS.BATCH_COUNTS, required: true },
      { name: 'totals', pattern: PATTERNS.BATCH_TOTALS, required: true },
      ACTOR,
    ],
  },
  {
    method: 'post', path: '/batch/runs/:id/control-totals', action: 'BATCH_CONTROL_TOTAL',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'totalCode', pattern: PATTERNS.BATCH_TOTAL_CODE, required: true },
      { name: 'expected', pattern: PATTERNS.AMOUNT, required: true },
      { name: 'actual', pattern: PATTERNS.AMOUNT, required: true },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/batch/eod', action: 'BATCH_EOD_START',
    tokenIdentity: 'actor',
    fields: [
      { name: 'businessDate', pattern: PATTERNS.DATE, required: true },
      { name: 'jobCode', pattern: PATTERNS.BATCH_CODE, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
];
