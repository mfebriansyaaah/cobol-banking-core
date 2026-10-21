import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const GL_ROUTES = [
  {
    method: 'get', path: '/gl/accounts', action: 'GL_ACCOUNT_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/gl/accounts', action: 'GL_ACCOUNT_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.GL_ACCOUNT, required: true },
      { name: 'name', pattern: PATTERNS.NAME, required: true },
      { name: 'type', pattern: PATTERNS.GL_TYPE, required: true },
      { name: 'normalSide', pattern: PATTERNS.GL_SIDE, required: true },
      { name: 'parent', pattern: PATTERNS.GL_ACCOUNT, required: false },
      ACTOR,
    ],
  },
  {
    method: 'post', path: '/gl/journals', action: 'GL_JOURNAL_POST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'date', pattern: PATTERNS.DATE, required: true },
      { name: 'description', pattern: PATTERNS.NAME, required: true },
      { name: 'debitAccount', pattern: PATTERNS.GL_ACCOUNT, required: true },
      { name: 'creditAccount', pattern: PATTERNS.GL_ACCOUNT, required: true },
      { name: 'amount', pattern: PATTERNS.GL_AMOUNT, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/gl/trial-balance', action: 'GL_TRIAL_BALANCE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'from', pattern: PATTERNS.DATE, required: true },
      { name: 'to', pattern: PATTERNS.DATE, required: true },
      { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
];
