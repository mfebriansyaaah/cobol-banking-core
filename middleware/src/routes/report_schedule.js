import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };
export const RPS_ROUTES = [
  { method: 'post', path: '/report-schedules/validate', action: 'RPS_VALIDATE', tokenIdentity: 'actor', fields: [ { name: 'amount', pattern: PATTERNS.AMOUNT, required: true }, { name: 'currency', pattern: PATTERNS.CURRENCY, required: true }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/report-schedules/summary', action: 'RPS_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/report-schedules/audit', action: 'RPS_AUDIT', tokenIdentity: 'actor', fields: [ { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/report-schedules', action: 'RPS_LIST', tokenIdentity: 'actor', fields: [ { name: 'status', pattern: PATTERNS.LIST_STATUS, required: false }, { name: 'scheduleType', pattern: PATTERNS.NAME, required: false }, { name: 'limit', pattern: PATTERNS.LIMIT, required: false }, { name: 'offset', pattern: PATTERNS.INT, required: false }, BLANK, ACTOR ] },
  { method: 'post', path: '/report-schedules', action: 'RPS_CREATE', tokenIdentity: 'actor', fields: [ { name: 'scheduleRef', pattern: PATTERNS.KEY, required: true }, { name: 'scheduleName', pattern: PATTERNS.NAME, required: true }, { name: 'scheduleType', pattern: PATTERNS.NAME, required: true }, BLANK, BLANK, ACTOR ] },
  { method: 'get', path: '/report-schedules/:id', action: 'RPS_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/report-schedules/:id/calc', action: 'RPS_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/report-schedules/:id/update', action: 'RPS_UPDATE', tokenIdentity: 'actor', fields: [ ID, { name: 'scheduleName', pattern: PATTERNS.NAME, required: false }, { name: 'scheduleType', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, ACTOR ] },
  { method: 'post', path: '/report-schedules/:id/delete', action: 'RPS_DELETE', tokenIdentity: 'actor', fields: [ ID, { name: 'reason', pattern: PATTERNS.NAME, required: false }, BLANK, BLANK, BLANK, ACTOR ] },
];
