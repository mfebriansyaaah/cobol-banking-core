import { PATTERNS } from '../validation.js';
const BLANK = {{ name: '', pattern: PATTERNS.PASSWORD, required: false }};
const ACTOR = {{ name: 'actor', pattern: PATTERNS.EMAIL, required: true }};
const ID = {{ name: 'id', pattern: PATTERNS.INT, required: true }};
export const CMD_ROUTES = [
  {{ method: 'post', path: '/commodities/validate', action: 'CMD_VALIDATE', tokenIdentity: 'actor', fields: [ {{ name: 'amount', pattern: PATTERNS.AMOUNT, required: true }}, {{ name: 'currency', pattern: PATTERNS.CURRENCY, required: true }}, BLANK, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/commodities/summary', action: 'CMD_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'get', path: '/commodities/audit', action: 'CMD_AUDIT', tokenIdentity: 'actor', fields: [ {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/commodities', action: 'CMD_LIST', tokenIdentity: 'actor', fields: [ {{ name: 'status', pattern: PATTERNS.CODE, required: false }}, {{ name: 'commodityType', pattern: PATTERNS.NAME, required: false }}, {{ name: 'limit', pattern: PATTERNS.LIMIT, required: false }}, {{ name: 'offset', pattern: PATTERNS.INT, required: false }}, BLANK, ACTOR ] }},
  {{ method: 'post', path: '/commodities', action: 'CMD_CREATE', tokenIdentity: 'actor', fields: [ {{ name: 'commodityRef', pattern: PATTERNS.KEY, required: true }}, {{ name: 'commodityName', pattern: PATTERNS.NAME, required: true }}, {{ name: 'commodityType', pattern: PATTERNS.NAME, required: true }}, BLANK, BLANK, ACTOR ] }},
  {{ method: 'get', path: '/commodities/:id', action: 'CMD_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'post', path: '/commodities/:id/calc', action: 'CMD_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] }},
  {{ method: 'post', path: '/commodities/:id/update', action: 'CMD_UPDATE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'commodityName', pattern: PATTERNS.NAME, required: false }}, {{ name: 'commodityType', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, ACTOR ] }},
  {{ method: 'post', path: '/commodities/:id/delete', action: 'CMD_DELETE', tokenIdentity: 'actor', fields: [ ID, {{ name: 'reason', pattern: PATTERNS.NAME, required: false }}, BLANK, BLANK, BLANK, ACTOR ] }},
];
