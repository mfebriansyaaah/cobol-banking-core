import { PATTERNS } from '../validation.js';
const BLANK = {{ name: '', pattern: PATTERNS.PASSWORD, required: false }};
const ACTOR = {{ name: 'actor', pattern: PATTERNS.EMAIL, required: true }};
const ID = {{ name: 'id', pattern: PATTERNS.INT, required: true }};
export const PIS_ROUTES = [
  {{ method: 'post', path: '/pisp-management/validate', action: 'PIS_VALIDATE', tokenIdentity: 'actor', fields: [ {{ name: 'amount', pattern: PATTERNS.AMOUNT, required: true }}, {{ name: 'currency', pattern: PATTERNS.CURRENCY, required: true }}, BLANK, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/pisp-management/summary', action: 'PIS_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'get', path: '/pisp-management/audit', action: 'PIS_AUDIT', tokenIdentity: 'actor', fields: [ {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/pisp-management', action: 'PIS_LIST', tokenIdentity: 'actor', fields: [ {{ name: 'status', pattern: PATTERNS.CODE, required: false }}, {{ name: 'pispType', pattern: PATTERNS.NAME, required: false }}, {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, ACTOR ] }},
  {{ method: 'post', path: '/pisp-management', action: 'PIS_CREATE', tokenIdentity: 'actor', fields: [ {{ name: 'pispRef', pattern: PATTERNS.KEY, required: true }}, {{ name: 'pispName', pattern: PATTERNS.NAME, required: true }}, {{ name: 'pispType', pattern: PATTERNS.NAME, required: true }}, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/pisp-management/:id', action: 'PIS_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'post', path: '/pisp-management/:id/calc', action: 'PIS_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'post', path: '/pisp-management/:id/update', action: 'PIS_UPDATE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'pispName', pattern: PATTERNS.NAME, required: false }}, {{ name: 'pispType', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, ACTOR ] }},
  {{ method: 'post', path: '/pisp-management/:id/delete', action: 'PIS_DELETE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'reason', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, BLANK, ACTOR ] }},
];
