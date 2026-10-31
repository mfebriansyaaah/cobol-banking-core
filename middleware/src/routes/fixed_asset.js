import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const FIXED_ASSET_ROUTES = [
  // DEPRECATED: stateless amount check; asset validation is POST /fixed-assets (capitalize guards).
  { method: 'post', path: '/finance/fixed-assets/validate', action: 'FAS_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/finance/fixed-assets/summary', action: 'FAS_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/finance/fixed-assets/audit', action: 'FAS_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/finance/fixed-assets', action: 'FAS_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/finance/fixed-assets', action: 'FAS_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'assetRef', pattern: PATTERNS.KEY, required: true },
    { name: 'assetName', pattern: PATTERNS.NAME, required: true },
    { name: 'assetType', pattern: PATTERNS.NAME, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/finance/fixed-assets/:id', action: 'FAS_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  // DEPRECATED: generic +1 calc; use POST /fixed-assets/:id/depreciate (straight-line schedule + period guard).
  { method: 'post', path: '/finance/fixed-assets/:id/depreciate', action: 'FAS_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  // DEPRECATED: generic metadata update; fixed assets are updated via capitalize/revalue/dispose lifecycle.
  { method: 'post', path: '/finance/fixed-assets/:id/update', action: 'FAS_UPDATE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'assetName', pattern: PATTERNS.NAME, required: false },
    { name: 'assetType', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  // DEPRECATED: generic close; use POST /fixed-assets/:id/dispose (gain/loss + GL link).
  { method: 'post', path: '/finance/fixed-assets/:id/dispose', action: 'FAS_DELETE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  // Domain fixed-asset lifecycle (FAS_CAPITALIZE/DEPRECIATE/REVALUE/DISPOSE).
  // Lives under /fixed-assets/* to avoid shadowing legacy /finance/fixed-assets/* above.
  { method: 'post', path: '/fixed-assets', action: 'FAS_CAPITALIZE', tokenIdentity: 'actor', fields: [
    { name: 'assetRef', pattern: PATTERNS.KEY, required: true },
    { name: 'assetName', pattern: PATTERNS.NAME, required: true },
    { name: 'assetType', pattern: PATTERNS.NAME, required: true },
    { name: 'costSpec', pattern: PATTERNS.RPT_PARAMS, required: true },
    { name: 'assetSpec', pattern: PATTERNS.RPT_PARAMS, required: true },
    ACTOR,
  ] },
  { method: 'get', path: '/fixed-assets/summary', action: 'FAS_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/fixed-assets/audit', action: 'FAS_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/fixed-assets', action: 'FAS_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/fixed-assets/:id', action: 'FAS_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/fixed-assets/:id/depreciate', action: 'FAS_DEPRECIATE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'period', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'glJournalId', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/fixed-assets/:id/revalue', action: 'FAS_REVALUE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'newBookValue', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'glJournalId', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/fixed-assets/:id/dispose', action: 'FAS_DISPOSE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'proceeds', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    { name: 'glJournalId', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
];
