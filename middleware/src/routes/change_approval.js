import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const CHANGE_APPROVAL_ROUTES = [
  { method: 'post', path: '/change/approvals/validate', action: 'CHA_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/change/approvals/summary', action: 'CHA_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/change/approvals/audit', action: 'CHA_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/change/approvals', action: 'CHA_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/change/approvals', action: 'CHA_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'changeRef', pattern: PATTERNS.KEY, required: true },
    { name: 'title', pattern: PATTERNS.NAME, required: true },
    { name: 'changeType', pattern: PATTERNS.NAME, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/change/approvals/:id', action: 'CHA_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/change/approvals/:id/calc', action: 'CHA_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/change/approvals/:id/delete', action: 'CHA_DELETE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
