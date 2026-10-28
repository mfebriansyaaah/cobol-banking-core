import { PATTERNS } from '../validation.js';
const BLANK = {{ name: '', pattern: PATTERNS.PASSWORD, required: false }};
const ACTOR = {{ name: 'actor', pattern: PATTERNS.EMAIL, required: true }};
const ID = {{ name: 'id', pattern: PATTERNS.INT, required: true }};
export const OPT_ROUTES = [
  {{ method: 'post', path: '/options/validate', action: 'OPT_VALIDATE', tokenIdentity: 'actor', fields: [ {{ name: 'amount', pattern: PATTERNS.AMOUNT, required: true }}, {{ name: 'currency', pattern: PATTERNS.CURRENCY, required: true }}, BLANK, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/options/summary', action: 'OPT_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'get', path: '/options/audit', action: 'OPT_AUDIT', tokenIdentity: 'actor', fields: [ {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/options', action: 'OPT_LIST', tokenIdentity: 'actor', fields: [ {{ name: 'status', pattern: PATTERNS.CODE, required: false }}, {{ name: 'optionType', pattern: PATTERNS.NAME, required: false }}, {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, ACTOR ] }},
  {{ method: 'post', path: '/options', action: 'OPT_CREATE', tokenIdentity: 'actor', fields: [ {{ name: 'optionRef', pattern: PATTERNS.KEY, required: true }}, {{ name: 'holderName', pattern: PATTERNS.NAME, required: true }}, {{ name: 'optionType', pattern: PATTERNS.NAME, required: true }}, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/options/:id', action: 'OPT_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'post', path: '/options/:id/calc', action: 'OPT_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'post', path: '/options/:id/update', action: 'OPT_UPDATE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'holderName', pattern: PATTERNS.NAME, required: false }}, {{ name: 'optionType', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, ACTOR ] }},
  {{ method: 'post', path: '/options/:id/delete', action: 'OPT_DELETE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'reason', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, BLANK, ACTOR ] }},
];
