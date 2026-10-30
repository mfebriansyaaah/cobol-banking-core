import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const TXM_ROUTES = [
  { method: 'post', path: '/tax-management/validate', action: 'TXM_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/tax-management/summary', action: 'TXM_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/tax-management/audit', action: 'TXM_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/tax-management', action: 'TXM_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.CODE, required: false }, { name: 'taxType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/tax-management', action: 'TXM_CREATE', tokenIdentity: 'actor', fields: [ { name: 'taxRef', pattern: PATTERNS.KEY, required: true }, { name: 'taxName', pattern: PATTERNS.NAME, required: true }, { name: 'taxType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/tax-management/:id', action: 'TXM_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  // DEPRECATED: generic +1 calc; use POST /tax/calculate (withholding engine).
  { method: 'post', path: '/tax-management/:id/calc', action: 'TXM_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  // DEPRECATED: generic metadata update; use /tax/rules/:id/update.
  { method: 'post', path: '/tax-management/:id/update', action: 'TXM_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'taxName', pattern: PATTERNS.NAME, required: false }, { name: 'taxType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  // DEPRECATED: generic close; withholding entries use POST/REVERSE lifecycle.
  { method: 'post', path: '/tax-management/:id/delete', action: 'TXM_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  // Domain withholding API (TXM_RULE_*/CALC/POST/REVERSE/REPORT). Lives under
  // /tax/* to avoid shadowing the legacy /tax-management/* routes above.
  { method: 'post', path: '/tax/rules', action: 'TXM_RULE_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'taxRef', pattern: PATTERNS.KEY, required: true },
    { name: 'taxName', pattern: PATTERNS.NAME, required: true },
    { name: 'taxType', pattern: PATTERNS.NAME, required: true },
    { name: 'rateSpec', pattern: PATTERNS.RPT_PARAMS, required: true },
    { name: 'ruleSpec', pattern: PATTERNS.RPT_PARAMS, required: true },
    ACTOR,
  ] },
  { method: 'get', path: '/tax/rules', action: 'TXM_RULE_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'taxType', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/tax/rules/:id', action: 'TXM_RULE_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/tax/rules/:id/update', action: 'TXM_RULE_UPDATE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'rateSpec', pattern: PATTERNS.RPT_PARAMS, required: false },
    { name: 'ruleSpec', pattern: PATTERNS.RPT_PARAMS, required: false },
    { name: 'enabled', pattern: PATTERNS.NAME, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/tax/calculate', action: 'TXM_CALC', tokenIdentity: 'actor', fields: [
    { name: 'ruleId', pattern: PATTERNS.INT, required: true },
    { name: 'sourceType', pattern: PATTERNS.NAME, required: true },
    { name: 'sourceRef', pattern: PATTERNS.KEY, required: true },
    { name: 'baseAmount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    ACTOR,
  ] },
  { method: 'post', path: '/tax/entries/:id/post', action: 'TXM_POST', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'glJournalId', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/tax/entries/:id/reverse', action: 'TXM_REVERSE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/tax/reports/run', action: 'TXM_REPORT', tokenIdentity: 'actor', fields: [
    { name: 'period', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'taxType', pattern: PATTERNS.NAME, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, ACTOR,
  ] },
];
