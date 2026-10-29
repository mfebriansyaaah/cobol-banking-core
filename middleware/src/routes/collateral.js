import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const CLT_ROUTES = [
  { method: 'post', path: '/collateral/validate', action: 'CLT_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/collateral/summary', action: 'CLT_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/collateral/audit', action: 'CLT_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/collateral', action: 'CLT_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/collateral', action: 'CLT_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'CLTRef', pattern: PATTERNS.KEY, required: true },
    { name: 'CLTName', pattern: PATTERNS.NAME, required: true },
    { name: 'CLTType', pattern: PATTERNS.NAME, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/collateral/:id', action: 'CLT_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/collateral/:id/calc', action: 'CLT_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/collateral/:id/update', action: 'CLT_UPDATE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'CLTName', pattern: PATTERNS.NAME, required: false },
    { name: 'CLTType', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/collateral/:id/delete', action: 'CLT_DELETE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/collateral/register', action: 'CLT_REGISTER', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: PATTERNS.KEY, required: true },
    { name: 'name', pattern: PATTERNS.NAME, required: true },
    { name: 'type', pattern: PATTERNS.NAME, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'customerRef', pattern: PATTERNS.KEY, required: false },
    ACTOR,
  ] },
  { method: 'post', path: '/collateral/:id/appraise', action: 'CLT_APPRAISE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'valuer', pattern: PATTERNS.NAME, required: false },
    { name: 'method', pattern: PATTERNS.NAME, required: false },
    { name: 'note', pattern: PATTERNS.NAME, required: false },
    ACTOR,
  ] },
  { method: 'post', path: '/collateral/:id/revalue', action: 'CLT_REVALUE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'valuer', pattern: PATTERNS.NAME, required: false },
    { name: 'method', pattern: PATTERNS.NAME, required: false },
    { name: 'note', pattern: PATTERNS.NAME, required: false },
    ACTOR,
  ] },
  { method: 'post', path: '/collateral/:id/pledge', action: 'CLT_PLEDGE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'loanId', pattern: PATTERNS.INT, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'haircut', pattern: PATTERNS.AMOUNT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/collateral/allocate', action: 'CLT_ALLOCATE', tokenIdentity: 'actor', fields: [
    { name: 'pledgeId', pattern: PATTERNS.INT, required: true },
    { name: 'loanId', pattern: PATTERNS.INT, required: true },
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/collateral/:id/release', action: 'CLT_RELEASE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/collateral/:id/repossess', action: 'CLT_REPOSSESS', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'loanId', pattern: PATTERNS.INT, required: false },
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    { name: 'glJournalId', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/collateral/:id/dispose', action: 'CLT_DISPOSE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'proceeds', pattern: PATTERNS.AMOUNT, required: false },
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    { name: 'glJournalId', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
];
