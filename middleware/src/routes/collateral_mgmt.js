import { PATTERNS } from '../validation.js';
// DEPRECATED: use /collateral (collateral_core) for new flows. Kept for backward compat.
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const CLM_ROUTES = [
  { method: 'post', path: '/collateral-mgmt/validate', action: 'CREP_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/collateral-mgmt/summary', action: 'CREP_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/collateral-mgmt/audit', action: 'CREP_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/collateral-mgmt', action: 'CREP_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'collateralType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/collateral-mgmt', action: 'CREP_CREATE', tokenIdentity: 'actor', fields: [ { name: 'collateralRef', pattern: PATTERNS.KEY, required: true }, { name: 'assetName', pattern: PATTERNS.NAME, required: true }, { name: 'collateralType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/collateral-mgmt/:id', action: 'CREP_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/collateral-mgmt/:id/calc', action: 'CREP_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/collateral-mgmt/:id/update', action: 'CREP_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'assetName', pattern: PATTERNS.NAME, required: false }, { name: 'collateralType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/collateral-mgmt/:id/delete', action: 'CREP_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
