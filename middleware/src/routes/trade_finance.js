import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
const GL = { name: 'glJournalId', pattern: PATTERNS.INT, required: false };
const TERMS = { name: 'terms', pattern: PATTERNS.RPT_PARAMS, required: true };

export const TRADE_FINANCE_ROUTES = [
  // Legacy generic trade_finance module (TRF_) — kept for compat; superseded by LC/BG flows.
  
  
  
  
  
  
  
  
  

  // Letter of Credit lifecycle.
  { method: 'post', path: '/trade-finance/lc', action: 'LOC_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: PATTERNS.KEY, required: true },
    { name: 'customerRef', pattern: PATTERNS.KEY, required: true },
    { name: 'beneficiary', pattern: PATTERNS.NAME, required: true },
    { name: 'lcType', pattern: PATTERNS.NAME, required: true },
    TERMS, ACTOR,
  ] },
  { method: 'post', path: '/trade-finance/lc/:id/submit', action: 'LOC_SUBMIT', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/trade-finance/lc/:id/approve', action: 'LOC_APPROVE', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/trade-finance/lc/:id/issue', action: 'LOC_ISSUE', tokenIdentity: 'actor', fields: [ID, GL, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/trade-finance/lc/:id/amend', action: 'LOC_AMEND', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'amountDelta', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'newExpiry', pattern: PATTERNS.DATE, required: false },
    { name: 'newTerms', pattern: PATTERNS.RPT_PARAMS, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/trade-finance/lc/:id/documents', action: 'LOC_DOCUMENT', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'docType', pattern: PATTERNS.NAME, required: true },
    { name: 'docRef', pattern: PATTERNS.KEY, required: true },
    { name: 'status', pattern: PATTERNS.NAME, required: true },
    { name: 'discrepancy', pattern: PATTERNS.NAME, required: false },
    ACTOR,
  ] },
  { method: 'post', path: '/trade-finance/lc/:id/draw', action: 'LOC_DRAW', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'drawingNo', pattern: PATTERNS.INT, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    { name: 'dueDate', pattern: PATTERNS.DATE, required: false },
    ACTOR,
  ] },
  { method: 'post', path: '/trade-finance/lc/drawings/:id/settle', action: 'LOC_SETTLE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'settledAmount', pattern: PATTERNS.AMOUNT, required: true },
    GL,
    { name: 'paymentClearingRef', pattern: PATTERNS.KEY, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/trade-finance/lc/:id/close', action: 'LOC_CLOSE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/trade-finance/lc/summary', action: 'LOC_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/trade-finance/lc/audit', action: 'LOC_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/trade-finance/lc', action: 'LOC_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/trade-finance/lc/:id', action: 'LOC_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },

  // Bank Guarantee lifecycle.
  { method: 'post', path: '/trade-finance/bg', action: 'BKG_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: PATTERNS.KEY, required: true },
    { name: 'customerRef', pattern: PATTERNS.KEY, required: true },
    { name: 'beneficiary', pattern: PATTERNS.NAME, required: true },
    { name: 'guaranteeType', pattern: PATTERNS.NAME, required: true },
    TERMS, ACTOR,
  ] },
  { method: 'post', path: '/trade-finance/bg/:id/submit', action: 'BKG_SUBMIT', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/trade-finance/bg/:id/approve', action: 'BKG_APPROVE', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/trade-finance/bg/:id/issue', action: 'BKG_ISSUE', tokenIdentity: 'actor', fields: [ID, GL, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/trade-finance/bg/:id/claims', action: 'BKG_CLAIM', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'claimRef', pattern: PATTERNS.KEY, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/trade-finance/bg/claims/:id/settle', action: 'BKG_SETTLE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'settledAmount', pattern: PATTERNS.AMOUNT, required: true },
    GL, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/trade-finance/bg/:id/close', action: 'BKG_CLOSE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/trade-finance/bg/summary', action: 'BKG_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/trade-finance/bg/audit', action: 'BKG_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/trade-finance/bg', action: 'BKG_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/trade-finance/bg/:id', action: 'BKG_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
