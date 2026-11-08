import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const RISK_ROUTES = [
  // Geo signals are resolved and hashed server-side from the request socket
  // (derivations.js): the client never sends country/ipHashFlags.
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
      { name: 'ipHashFlags', pattern: PATTERNS.IP_HASH_FLAGS, required: false },
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
