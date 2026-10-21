import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const REPORT_DELIVERY_ROUTES = [
  {
    method: 'post', path: '/reports/layouts/:template', action: 'RDL_LAYOUT_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'template', pattern: PATTERNS.RPT_CODE, required: true },
      { name: 'page', pattern: PATTERNS.RPT_PAGE_SPEC, required: true },
      { name: 'header', pattern: PATTERNS.BATCH_DETAIL, required: false },
      { name: 'footer', pattern: PATTERNS.BATCH_DETAIL, required: false },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/layouts/:template', action: 'RDL_LAYOUT_GET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'template', pattern: PATTERNS.RPT_CODE, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/layouts', action: 'RDL_LAYOUT_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/runs/:id/render', action: 'RDL_LAYOUT_RENDER',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reports/schedules', action: 'RDL_SCHEDULE_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'template', pattern: PATTERNS.RPT_CODE, required: true },
      { name: 'frequency', pattern: PATTERNS.SCHEDULE_FREQ, required: true },
      { name: 'time', pattern: PATTERNS.SCHEDULE_TIME, required: true },
      { name: 'recipient', pattern: PATTERNS.EMAIL, required: true },
      { name: 'output', pattern: PATTERNS.SCHEDULE_OUTPUT, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/schedules', action: 'RDL_SCHEDULE_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reports/schedules/due', action: 'RDL_SCHEDULE_DUE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'asOf', pattern: PATTERNS.DATE, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'put', path: '/reports/schedules/:id', action: 'RDL_SCHEDULE_UPDATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
      { name: 'frequency', pattern: PATTERNS.SCHEDULE_FREQ, required: true },
      { name: 'time', pattern: PATTERNS.SCHEDULE_TIME, required: true },
      { name: 'output', pattern: PATTERNS.SCHEDULE_OUTPUT, required: true },
      ACTOR,
    ],
  },
  {
    method: 'delete', path: '/reports/schedules/:id', action: 'RDL_SCHEDULE_DELETE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reports/schedules/:id/run', action: 'RDL_SCHEDULE_RUN',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'from', pattern: PATTERNS.DATE, required: true },
      { name: 'to', pattern: PATTERNS.DATE, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
];
