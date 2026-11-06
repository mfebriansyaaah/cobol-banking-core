import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const FX_ROUTES = [
  {
    method: 'post',
    path: '/fx/rates',
    action: 'FX_RATE_STORE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'base', pattern: PATTERNS.CURRENCY, required: true },
      { name: 'quote', pattern: PATTERNS.CURRENCY, required: true },
      { name: 'rate', pattern: PATTERNS.AMOUNT, required: true },
      { name: 'provider', pattern: PATTERNS.NAME, required: false },
      { name: 'date', pattern: PATTERNS.DATE, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/fx/rates',
    action: 'FX_RATE_GET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'base', pattern: PATTERNS.CURRENCY, required: true },
      { name: 'quote', pattern: PATTERNS.CURRENCY, required: true },
      BLANK,
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
];
