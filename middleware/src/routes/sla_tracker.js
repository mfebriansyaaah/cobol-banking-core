import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const SLT_ROUTES = [
  {
    method: 'post',
    path: '/sla-trackers/validate',
    action: 'SLT_VALIDATE',
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
    path: '/sla-trackers/summary',
    action: 'SLT_SUMMARY',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/sla-trackers/audit',
    action: 'SLT_AUDIT',
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
    path: '/sla-trackers',
    action: 'SLT_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'status', pattern: PATTERNS.LIST_STATUS, required: false },
      { name: 'slaType', pattern: PATTERNS.NAME, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/sla-trackers',
    action: 'SLT_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'slaRef', pattern: PATTERNS.KEY, required: true },
      { name: 'slaName', pattern: PATTERNS.NAME, required: true },
      { name: 'slaType', pattern: PATTERNS.NAME, required: true },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/sla-trackers/:id',
    action: 'SLT_GET',
    tokenIdentity: 'actor',
    fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/sla-trackers/:id/calc',
    action: 'SLT_CALC',
    tokenIdentity: 'actor',
    fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/sla-trackers/:id/update',
    action: 'SLT_UPDATE',
    tokenIdentity: 'actor',
    fields: [
      ID,
      { name: 'slaName', pattern: PATTERNS.NAME, required: false },
      { name: 'slaType', pattern: PATTERNS.NAME, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/sla-trackers/:id/delete',
    action: 'SLT_DELETE',
    tokenIdentity: 'actor',
    fields: [ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR],
  },
];
