import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const RECON_ROUTES = [
  {
    method: 'post', path: '/reconciliation/findings/:id/notes', action: 'RECON_NOTE_ADD',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reconciliation/findings/:id/notes', action: 'RECON_NOTE_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reconciliation/findings/:id/assign', action: 'RECON_ASSIGN',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'owner', pattern: PATTERNS.EMAIL, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reconciliation/summary', action: 'RECON_SUMMARY',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get', path: '/reconciliation/aging', action: 'RECON_AGING',
    tokenIdentity: 'actor',
    fields: [
      { name: 'status', pattern: PATTERNS.RECON_STATUS, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reconciliation/trend', action: 'RECON_TREND',
    tokenIdentity: 'actor',
    fields: [
      { name: 'days', pattern: PATTERNS.INT, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reconciliation/export', action: 'RECON_EXPORT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'status', pattern: PATTERNS.RECON_STATUS, required: false },
      { name: 'format', pattern: PATTERNS.RPT_FORMAT, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reconciliation/sla', action: 'RECON_SLA_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'ageHours', pattern: PATTERNS.INT, required: true },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reconciliation/sla', action: 'RECON_SLA_GET',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
];
