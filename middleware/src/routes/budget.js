import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const BUDGET_ROUTES = [
  { method: 'post', path: '/budgets', action: 'BUD_LINE_SET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'costCenter', pattern: PATTERNS.REF_CODE, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'period', pattern: PATTERNS.BUD_PERIOD, required: true },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/budgets', action: 'BUD_LINE_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/budgets/:code/spend', action: 'BUD_SPEND', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/budgets/summary', action: 'BUD_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
