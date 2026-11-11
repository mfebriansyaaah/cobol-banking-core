import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const INT = { name: 'id', pattern: PATTERNS.INT, required: true };
export const LOAN_SCHEDULE_ROUTES = [
  {
    method: 'post',
    path: '/loans/:id/schedule',
    action: 'LSC_CREATE',
    tokenIdentity: 'actor',
    fields: [
      INT,
      { name: 'term', pattern: PATTERNS.TERM, required: true },
      { name: 'rate', pattern: PATTERNS.RATE, required: false },
      { name: 'startDate', pattern: PATTERNS.DATE, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/loans/schedules/search',
    action: 'LSC_SEARCH',
    tokenIdentity: 'actor',
    fields: [{ name: 'q', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/loans/schedules/:id',
    action: 'LSC_DETAIL',
    tokenIdentity: 'actor',
    fields: [INT, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/loans/:id/schedules',
    action: 'LSC_LIST',
    tokenIdentity: 'actor',
    fields: [
      INT,
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'put',
    path: '/loans/schedules/:id',
    action: 'LSC_UPDATE',
    tokenIdentity: 'actor',
    fields: [
      INT,
      { name: 'term', pattern: PATTERNS.TERM, required: false },
      { name: 'rate', pattern: PATTERNS.RATE, required: false },
      { name: 'startDate', pattern: PATTERNS.DATE, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'delete',
    path: '/loans/schedules/:id',
    action: 'LSC_DELETE',
    tokenIdentity: 'actor',
    fields: [INT, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/loans/schedules/:id/history',
    action: 'LSC_HISTORY',
    tokenIdentity: 'actor',
    fields: [INT, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
];
