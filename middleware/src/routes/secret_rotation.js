import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const SECRET_ROTATION_ROUTES = [
  { method: 'post', path: '/secret-rotations', action: 'SCR_SCHEDULE', tokenIdentity: 'actor', fields: [
    { name: 'name', pattern: PATTERNS.KEY, required: true },
    { name: 'nextRotation', pattern: PATTERNS.PASSWORD, required: true },
    { name: 'overlap', pattern: PATTERNS.KRO_OVERLAP, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/secret-rotations', action: 'SCR_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.KRO_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/secret-rotations/summary', action: 'SCR_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/secret-rotations/:id', action: 'SCR_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/secret-rotations/:id/rotate', action: 'SCR_ROTATE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/secret-rotations/:id/verify', action: 'SCR_VERIFY', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
];
