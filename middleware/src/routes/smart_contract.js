import { PATTERNS } from '../validation.js';
const BLANK = {{ name: '', pattern: PATTERNS.PASSWORD, required: false }};
const ACTOR = {{ name: 'actor', pattern: PATTERNS.EMAIL, required: true }};
const ID = {{ name: 'id', pattern: PATTERNS.INT, required: true }};
export const SMC_ROUTES = [
  {{ method: 'post', path: '/smart-contracts/validate', action: 'SMC_VALIDATE', tokenIdentity: 'actor', fields: [ {{ name: 'amount', pattern: PATTERNS.AMOUNT, required: true }}, {{ name: 'currency', pattern: PATTERNS.CURRENCY, required: true }}, BLANK, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/smart-contracts/summary', action: 'SMC_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'get', path: '/smart-contracts/audit', action: 'SMC_AUDIT', tokenIdentity: 'actor', fields: [ {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/smart-contracts', action: 'SMC_LIST', tokenIdentity: 'actor', fields: [ {{ name: 'status', pattern: PATTERNS.CODE, required: false }}, {{ name: 'contractType', pattern: PATTERNS.NAME, required: false }}, {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, ACTOR ] }},
  {{ method: 'post', path: '/smart-contracts', action: 'SMC_CREATE', tokenIdentity: 'actor', fields: [ {{ name: 'contractRef', pattern: PATTERNS.KEY, required: true }}, {{ name: 'contractName', pattern: PATTERNS.NAME, required: true }}, {{ name: 'contractType', pattern: PATTERNS.NAME, required: true }}, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/smart-contracts/:id', action: 'SMC_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'post', path: '/smart-contracts/:id/calc', action: 'SMC_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'post', path: '/smart-contracts/:id/update', action: 'SMC_UPDATE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'contractName', pattern: PATTERNS.NAME, required: false }}, {{ name: 'contractType', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, ACTOR ] }},
  {{ method: 'post', path: '/smart-contracts/:id/delete', action: 'SMC_DELETE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'reason', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, BLANK, ACTOR ] }},
];
