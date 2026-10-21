import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const ALERT_ROUTES = [
  {
    method: 'post', path: '/alerts', action: 'ALT_RAISE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.ALT_TYPE, required: true },
      { name: 'severity', pattern: PATTERNS.ALT_SEVERITY, required: true },
      { name: 'source', pattern: PATTERNS.KEY, required: true },
      { name: 'title', pattern: PATTERNS.NTF_TEXT, required: true },
      { name: 'detail', pattern: PATTERNS.NTF_TEXT, required: false },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/alerts', action: 'ALT_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'state', pattern: PATTERNS.ALT_STATE, required: false },
      { name: 'severity', pattern: PATTERNS.ALT_SEVERITY, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/alerts/summary', action: 'ALT_SUMMARY',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post', path: '/alerts/scan/outbox', action: 'ALT_SCAN_OUTBOX',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/alerts/scan/schedules', action: 'ALT_SCAN_SCHEDULE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'asOf', pattern: PATTERNS.DATE, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/alerts/scan/recon', action: 'ALT_SCAN_RECON',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/alerts/scan/disputes', action: 'ALT_SCAN_DISPUTE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'asOf', pattern: PATTERNS.DATE, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/alerts/:id', action: 'ALT_GET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/alerts/:id/history', action: 'ALT_HISTORY',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/alerts/:id/ack', action: 'ALT_ACK',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'owner', pattern: PATTERNS.EMAIL, required: true },
      { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/alerts/:id/resolve', action: 'ALT_RESOLVE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/alerts/:id/note', action: 'ALT_NOTE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
];
