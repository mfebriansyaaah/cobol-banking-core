import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: null, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const LOAN_ROUTES = [
  { method: 'post', path: '/loans', action: 'LOAN_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
