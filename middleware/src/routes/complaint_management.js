import { PATTERNS } from '../validation.js';
const BLANK = {{ name: '', pattern: PATTERNS.PASSWORD, required: false }};
const ACTOR = {{ name: 'actor', pattern: PATTERNS.EMAIL, required: true }};
const ID = {{ name: 'id', pattern: PATTERNS.INT, required: true }};
export const CPM_ROUTES = [
  {{ method: 'post', path: '/complaints/validate', action: 'CPM_VALIDATE', tokenIdentity: 'actor', fields: [ {{ name: 'amount', pattern: PATTERNS.AMOUNT, required: true }}, {{ name: 'currency', pattern: PATTERNS.CURRENCY, required: true }}, BLANK, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/complaints/summary', action: 'CPM_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'get', path: '/complaints/audit', action: 'CPM_AUDIT', tokenIdentity: 'actor', fields: [ {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/complaints', action: 'CPM_LIST', tokenIdentity: 'actor', fields: [ {{ name: 'status', pattern: PATTERNS.CODE, required: false }}, {{ name: 'complaintType', pattern: PATTERNS.NAME, required: false }}, {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, ACTOR ] }},
  {{ method: 'post', path: '/complaints', action: 'CPM_CREATE', tokenIdentity: 'actor', fields: [ {{ name: 'complaintRef', pattern: PATTERNS.KEY, required: true }}, {{ name: 'complainantName', pattern: PATTERNS.NAME, required: true }}, {{ name: 'complaintType', pattern: PATTERNS.NAME, required: true }}, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/complaints/:id', action: 'CPM_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'post', path: '/complaints/:id/calc', action: 'CPM_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'post', path: '/complaints/:id/update', action: 'CPM_UPDATE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'complainantName', pattern: PATTERNS.NAME, required: false }}, {{ name: 'complaintType', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, ACTOR ] }},
  {{ method: 'post', path: '/complaints/:id/delete', action: 'CPM_DELETE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'reason', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, BLANK, ACTOR ] }},
];
