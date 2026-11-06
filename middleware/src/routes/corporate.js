import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const CORPORATE_ROUTES = [
  {
    method: 'post', path: '/corporate/resolve', action: 'CORP_RESOLVE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'lei', pattern: PATTERNS.KEY, required: true },
      { name: 'legalName', pattern: PATTERNS.NAME, required: true },
      { name: 'status', pattern: PATTERNS.NAME, required: true },
      { name: 'address', pattern: PATTERNS.NAME, required: false },
      { name: 'date', pattern: PATTERNS.DATE, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/corporate/status', action: 'CORP_STATUS',
    tokenIdentity: 'actor',
    fields: [
      { name: 'lei', pattern: PATTERNS.KEY, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
];
