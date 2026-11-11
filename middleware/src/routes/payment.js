import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const PAYMENT_ROUTES = [
  {
    method: 'post',
    path: '/payments/policies',
    action: 'PAY_POLICY_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
      { name: 'limits', pattern: PATTERNS.PAY_POLICY_SPEC, required: true },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/payments/policies',
    action: 'PAY_POLICY_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'currency', pattern: PATTERNS.CURRENCY, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/payments/policies/:currency',
    action: 'PAY_POLICY_GET',
    tokenIdentity: 'actor',
    fields: [{ name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/payments/profiles',
    action: 'PAY_PROFILE_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
      { name: 'limits', pattern: PATTERNS.PAY_PROFILE_SPEC, required: true },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/payments/profiles/:email',
    action: 'PAY_PROFILE_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/payments/usage/:email/:currency',
    action: 'PAY_DAILY_USAGE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
      BLANK,
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/payments/check',
    action: 'PAY_CHECK',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
      { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
];
