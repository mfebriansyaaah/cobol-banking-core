import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const SGC_ROUTES = [
  { method: 'post', path: '/system-configs/validate', action: 'SGC_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/system-configs/summary', action: 'SGC_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/system-configs/audit', action: 'SGC_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/system-configs', action: 'SGC_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'configType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/system-configs', action: 'SGC_CREATE', tokenIdentity: 'actor', fields: [ { name: 'configRef', pattern: PATTERNS.KEY, required: true }, { name: 'configName', pattern: PATTERNS.NAME, required: true }, { name: 'configType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/system-configs/:id', action: 'SGC_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/system-configs/:id/calc', action: 'SGC_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/system-configs/:id/update', action: 'SGC_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'configName', pattern: PATTERNS.NAME, required: false }, { name: 'configType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/system-configs/:id/delete', action: 'SGC_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
