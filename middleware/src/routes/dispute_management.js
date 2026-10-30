import { PATTERNS } from '../validation.js';
// DEPRECATED: generic template clone. Card disputes use /chargebacks/* (chargeback_core); ledger disputes use /disputes (wallet_core). Kept for backward compat.
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const DSM_ROUTES = [
  { method: 'post', path: '/dispute-management/validate', action: 'DSM_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/dispute-management/summary', action: 'DSM_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dispute-management/audit', action: 'DSM_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/dispute-management', action: 'DSM_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'disputeType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/dispute-management', action: 'DSM_CREATE', tokenIdentity: 'actor', fields: [ { name: 'disputeRef', pattern: PATTERNS.KEY, required: true }, { name: 'disputantName', pattern: PATTERNS.NAME, required: true }, { name: 'disputeType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/dispute-management/:id', action: 'DSM_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/dispute-management/:id/calc', action: 'DSM_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/dispute-management/:id/update', action: 'DSM_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'disputantName', pattern: PATTERNS.NAME, required: false }, { name: 'disputeType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/dispute-management/:id/delete', action: 'DSM_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
