import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const DISPUTE_OPS_ROUTES = [
  {
    method: 'post', path: '/disputes/sla', action: 'DSP_SLA_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'priority', pattern: PATTERNS.DSP_PRIORITY, required: true },
      { name: 'hours', pattern: PATTERNS.DSP_SLA_SPEC, required: true },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/disputes/sla', action: 'DSP_SLA_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'priority', pattern: PATTERNS.DSP_PRIORITY, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/disputes/sla/:priority', action: 'DSP_SLA_GET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'priority', pattern: PATTERNS.DSP_PRIORITY, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'put', path: '/disputes/:id/priority', action: 'DSP_PRIORITY_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'priority', pattern: PATTERNS.DSP_PRIORITY, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/disputes/:id/assign', action: 'DSP_ASSIGN',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'assignee', pattern: PATTERNS.EMAIL, required: true },
      { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'put', path: '/disputes/:id/due', action: 'DSP_DUE_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'due', pattern: PATTERNS.DATE, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/disputes/queue', action: 'DSP_QUEUE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'state', pattern: PATTERNS.DISPUTE_STATUS, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'assignee', pattern: PATTERNS.EMAIL, required: false },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/disputes/overdue', action: 'DSP_OVERDUE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'asOf', pattern: PATTERNS.DATE, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/disputes/:id/escalate', action: 'DSP_ESCALATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'manager', pattern: PATTERNS.EMAIL, required: true },
      { name: 'reason', pattern: PATTERNS.BATCH_DETAIL, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/disputes/summary', action: 'DSP_SUMMARY',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get', path: '/disputes/aging', action: 'DSP_AGING',
    tokenIdentity: 'actor',
    fields: [
      { name: 'state', pattern: PATTERNS.DISPUTE_STATUS, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/disputes/:id/history', action: 'DSP_HISTORY',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
];
