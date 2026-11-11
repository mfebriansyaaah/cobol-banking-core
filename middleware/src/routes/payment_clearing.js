import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const PAYMENT_CLEARING_ROUTES = [
  {
    method: 'post',
    path: '/payments/clearing/validate',
    action: 'PMC_VALIDATE',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/payments/clearing/summary',
    action: 'PMC_SUMMARY',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/payments/clearing/audit',
    action: 'PMC_AUDIT',
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
    path: '/payments/clearing',
    action: 'PMC_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'status', pattern: PATTERNS.PMC_LIST_STATUS, required: false },
      { name: 'currency', pattern: PATTERNS.CURRENCY, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/payments/clearing',
    action: 'PMC_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'clearingRef', pattern: PATTERNS.KEY, required: true },
      { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
      { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
      { name: 'paymentRef', pattern: PATTERNS.KEY, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/payments/clearing/:id',
    action: 'PMC_GET',
    tokenIdentity: 'actor',
    fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/payments/clearing/:id/post',
    action: 'PMC_POST',
    tokenIdentity: 'actor',
    fields: [ID, { name: 'amount', pattern: PATTERNS.AMOUNT, required: false }, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/payments/clearing/:id/settle',
    action: 'PMC_SETTLE',
    tokenIdentity: 'actor',
    fields: [
      ID,
      { name: 'amount', pattern: PATTERNS.AMOUNT, required: false },
      BLANK,
      BLANK,
      { name: 'idempotencyKey', pattern: PATTERNS.KEY, required: false },
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/payments/clearing/:id/cancel',
    action: 'PMC_CANCEL',
    tokenIdentity: 'actor',
    fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
];
