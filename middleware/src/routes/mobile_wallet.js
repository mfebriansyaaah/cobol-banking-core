import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const MBW_ROUTES = [
  { method: 'post', path: '/mobile-wallets/validate', action: 'MBW_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/mobile-wallets/summary', action: 'MBW_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/mobile-wallets/audit', action: 'MBW_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/mobile-wallets', action: 'MBW_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'walletType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/mobile-wallets', action: 'MBW_CREATE', tokenIdentity: 'actor', fields: [ { name: 'walletRef', pattern: PATTERNS.KEY, required: true }, { name: 'walletName', pattern: PATTERNS.NAME, required: true }, { name: 'walletType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/mobile-wallets/:id', action: 'MBW_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/mobile-wallets/:id/calc', action: 'MBW_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/mobile-wallets/:id/update', action: 'MBW_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'walletName', pattern: PATTERNS.NAME, required: false }, { name: 'walletType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/mobile-wallets/:id/delete', action: 'MBW_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
