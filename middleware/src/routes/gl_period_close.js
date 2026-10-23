import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const GL_PERIOD_CLOSE_ROUTES = [
  { method: 'post', path: '/gl/periods/:period/lock', action: 'GPC_LOCK', tokenIdentity: 'actor', fields: [
    { name: 'period', pattern: PATTERNS.GL_PERIOD, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/gl/periods/:period/unlock', action: 'GPC_UNLOCK', tokenIdentity: 'actor', fields: [
    { name: 'period', pattern: PATTERNS.GL_PERIOD, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/gl/periods/:period/close', action: 'GPC_CLOSE', tokenIdentity: 'actor', fields: [
    { name: 'period', pattern: PATTERNS.GL_PERIOD, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/gl/periods', action: 'GPC_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.GPC_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/gl/period-summary', action: 'GPC_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
