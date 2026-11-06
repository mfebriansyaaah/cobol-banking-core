import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const RISK_ROUTES = [
  {
    method: 'post',
    path: '/risk/note',
    action: 'RISK_NOTE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'country', pattern: PATTERNS.NAME, required: false },
      { name: 'city', pattern: PATTERNS.NAME, required: false },
      { name: 'asn', pattern: PATTERNS.NAME, required: false },
      { name: 'ipHashFlags', pattern: PATTERNS.REF_VALUE_CODE, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/risk/status',
    action: 'RISK_STATUS',
    tokenIdentity: 'actor',
    fields: [{ name: 'email', pattern: PATTERNS.EMAIL, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
];
