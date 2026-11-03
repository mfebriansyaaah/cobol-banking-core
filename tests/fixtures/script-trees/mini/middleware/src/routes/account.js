import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: null, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const ACCOUNT_ROUTES = [
  { method: 'post', path: '/accounts', action: 'ACC_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'accountRef', pattern: PATTERNS.KEY, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/accounts/:id', action: 'ACC_GET', tokenIdentity: 'actor', fields: [
    BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
];
