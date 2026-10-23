import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const GL_REVAL_ROUTES = [
  { method: 'post', path: '/gl/revaluations', action: 'GRL_RUN_START', tokenIdentity: 'actor', fields: [
    { name: 'period', pattern: PATTERNS.GL_PERIOD, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/gl/revaluations/:id/lines', action: 'GRL_LINE_ADD', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'account', pattern: PATTERNS.GL_ACCOUNT, required: true },
    { name: 'original', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'revalued', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'detail', pattern: PATTERNS.BATCH_DETAIL, required: false },
    ACTOR,
  ] },
  { method: 'post', path: '/gl/revaluations/:id/complete', action: 'GRL_RUN_COMPLETE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'matched', pattern: PATTERNS.BATCH_COUNT, required: true },
    { name: 'diff', pattern: PATTERNS.AMOUNT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/gl/revaluations', action: 'GRL_RUN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.GRL_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/gl/revaluations/:id', action: 'GRL_RUN_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/gl/revaluation-summary', action: 'GRL_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
