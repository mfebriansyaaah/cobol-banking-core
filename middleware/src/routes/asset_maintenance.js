import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const ASSET_MAINTENANCE_ROUTES = [
  { method: 'post', path: '/assets/:code/maintenance', action: 'AMT_ADD', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'type', pattern: PATTERNS.BATCH_DETAIL, required: true },
    { name: 'cost', pattern: PATTERNS.AMOUNT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/assets/maintenance', action: 'AMT_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/assets/maintenance-summary', action: 'AMT_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
