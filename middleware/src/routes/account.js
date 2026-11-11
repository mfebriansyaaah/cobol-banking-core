import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const ACCOUNT_ROUTES = [
  {
    method: 'post',
    path: '/accounts/validate',
    action: 'ACC_VALIDATE',
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
    path: '/accounts/summary',
    action: 'ACC_SUMMARY',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/accounts/audit',
    action: 'ACC_AUDIT',
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
    path: '/accounts',
    action: 'ACC_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'status', pattern: PATTERNS.LIST_STATUS, required: false },
      { name: 'type', pattern: PATTERNS.NAME, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/accounts',
    action: 'ACC_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'accountRef', pattern: PATTERNS.KEY, required: true },
      { name: 'holderName', pattern: PATTERNS.NAME, required: true },
      { name: 'accountType', pattern: PATTERNS.NAME, required: true },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/accounts/:id',
    action: 'ACC_GET',
    tokenIdentity: 'actor',
    fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/accounts/:id/calc',
    action: 'ACC_CALC',
    tokenIdentity: 'actor',
    fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/accounts/:id/update',
    action: 'ACC_UPDATE',
    tokenIdentity: 'actor',
    fields: [
      ID,
      { name: 'holderName', pattern: PATTERNS.NAME, required: false },
      { name: 'accountType', pattern: PATTERNS.NAME, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/accounts/:id/delete',
    action: 'ACC_DELETE',
    tokenIdentity: 'actor',
    fields: [ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR],
  },
];
