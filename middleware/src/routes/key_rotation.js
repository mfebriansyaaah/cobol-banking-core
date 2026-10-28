import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const KEY_ROTATION_ROUTES = [
  { method: 'post', path: '/key-rotations', action: 'KRO_PLAN_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'keyName', pattern: PATTERNS.KEY, required: true },
    { name: 'overlap', pattern: PATTERNS.KRO_OVERLAP, required: true },
    { name: 'nextRotation', pattern: PATTERNS.PASSWORD, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/key-rotations', action: 'KRO_PLAN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.KRO_STATUS, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/key-rotations/due', action: 'KRO_DUE', tokenIdentity: 'actor', fields: [
    { name: 'date', pattern: PATTERNS.DATE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/key-rotations/summary', action: 'KRO_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/key-rotations/:id', action: 'KRO_PLAN_GET', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/key-rotations/:id/rotate', action: 'KRO_ROTATE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/key-rotations/:id/complete', action: 'KRO_COMPLETE', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/key-rotations/:id/cancel', action: 'KRO_CANCEL', tokenIdentity: 'actor', fields: [
    { name: 'id', pattern: PATTERNS.INT, required: true },
    { name: 'reason', pattern: PATTERNS.BATCH_DETAIL, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
