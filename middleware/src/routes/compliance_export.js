import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const COMPLIANCE_EXPORT_ROUTES = [
  { method: 'post', path: '/compliance/packages', action: 'CEX_PACKAGE_SAVE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'framework', pattern: PATTERNS.CEX_FRAMEWORK, required: true },
    { name: 'title', pattern: PATTERNS.RPT_NAME, required: true },
    { name: 'start', pattern: PATTERNS.DATE, required: true },
    { name: 'end', pattern: PATTERNS.DATE, required: true },
    ACTOR,
  ] },
  { method: 'get', path: '/compliance/packages', action: 'CEX_PACKAGE_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CEX_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/packages/:code', action: 'CEX_PACKAGE_GET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/compliance/packages/:code/items', action: 'CEX_ITEM_ADD', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'type', pattern: PATTERNS.CEX_ITEM, required: true },
    { name: 'ref', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'delete', path: '/compliance/packages/:code/items/:type/:ref', action: 'CEX_ITEM_REMOVE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'type', pattern: PATTERNS.CEX_ITEM, required: true },
    { name: 'ref', pattern: PATTERNS.RPT_CHECKSUM, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/packages/:code/items', action: 'CEX_ITEM_LIST', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/compliance/packages/:code/seal', action: 'CEX_SEAL', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/compliance/packages/:code/attest', action: 'CEX_ATTEST', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/compliance/packages/:code/revoke', action: 'CEX_REVOKE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'reason', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/packages/:code/verify', action: 'CEX_VERIFY', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/summary', action: 'CEX_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
