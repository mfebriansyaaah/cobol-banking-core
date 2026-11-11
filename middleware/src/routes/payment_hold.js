import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const PAYMENT_HOLD_ROUTES = [
  {
    method: 'post',
    path: '/holds',
    action: 'PHL_RESERVE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'account', pattern: PATTERNS.INT, required: true },
      { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
      { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
      { name: 'expires', pattern: PATTERNS.DATE, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/holds',
    action: 'PHL_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'account', pattern: PATTERNS.INT, required: false },
      { name: 'status', pattern: PATTERNS.PHL_STATUS, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/holds/expire',
    action: 'PHL_EXPIRE',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/holds/stats',
    action: 'PHL_SUMMARY',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/holds/:id/capture',
    action: 'PHL_CAPTURE',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/holds/:id/release',
    action: 'PHL_RELEASE',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/holds/:id',
    action: 'PHL_GET',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
];
