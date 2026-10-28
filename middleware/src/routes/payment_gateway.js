import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const PWG_ROUTES = [
  { method: 'post', path: '/payment-gateways/validate', action: 'PWG_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/payment-gateways/summary', action: 'PWG_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/payment-gateways/audit', action: 'PWG_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/payment-gateways', action: 'PWG_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'gatewayType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/payment-gateways', action: 'PWG_CREATE', tokenIdentity: 'actor', fields: [ { name: 'gatewayRef', pattern: PATTERNS.KEY, required: true }, { name: 'gatewayName', pattern: PATTERNS.NAME, required: true }, { name: 'gatewayType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/payment-gateways/:id', action: 'PWG_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/payment-gateways/:id/calc', action: 'PWG_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/payment-gateways/:id/update', action: 'PWG_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'gatewayName', pattern: PATTERNS.NAME, required: false }, { name: 'gatewayType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/payment-gateways/:id/delete', action: 'PWG_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
