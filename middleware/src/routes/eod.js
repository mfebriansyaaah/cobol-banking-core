import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const EOD_ROUTES = [
  {
    method: 'post',
    path: '/eod/calendars',
    action: 'EOD_CAL_OPEN',
    tokenIdentity: 'actor',
    fields: [
      { name: 'date', pattern: PATTERNS.DATE, required: true },
      { name: 'cutoff', pattern: PATTERNS.EOD_TIME, required: true },
      BLANK,
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/eod/calendars',
    action: 'EOD_CAL_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'status', pattern: PATTERNS.EOD_STATUS, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/eod/runs',
    action: 'EOD_RUN_START',
    tokenIdentity: 'actor',
    fields: [{ name: 'date', pattern: PATTERNS.DATE, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/eod/runs/:id/phases/:code',
    action: 'EOD_PHASE_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'code', pattern: PATTERNS.EOD_PHASE_CODE, required: true },
      { name: 'status', pattern: PATTERNS.EOD_PHASE_STATUS, required: true },
      { name: 'counts', pattern: PATTERNS.EOD_COUNTS, required: true },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/eod/runs/:id',
    action: 'EOD_RUN_STATUS',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'details', pattern: PATTERNS.FLAG, required: false },
      BLANK,
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/eod/runs/:id/close',
    action: 'EOD_RUN_CLOSE',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/eod/runs/:id/fail',
    action: 'EOD_RUN_FAIL',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'errorCode', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/eod/runs',
    action: 'EOD_RUN_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'status', pattern: PATTERNS.EOD_RUN_STATUS, required: false },
      { name: 'date', pattern: PATTERNS.DATE, required: false },
      BLANK,
      ACTOR,
    ],
  },
];
