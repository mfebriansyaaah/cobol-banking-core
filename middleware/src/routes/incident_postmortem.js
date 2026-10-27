import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

export const INCIDENT_POSTMORTEM_ROUTES = [
  { method: 'post', path: '/ops/incidents/validate', action: 'IPM_VALIDATE', tokenIdentity: 'actor', fields: [
    { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
    { name: 'currency', pattern: PATTERNS.CURRENCY, required: true },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/ops/incidents/summary', action: 'IPM_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/ops/incidents/audit', action: 'IPM_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/ops/incidents', action: 'IPM_LIST', tokenIdentity: 'actor', fields: [
    { name: 'status', pattern: PATTERNS.CODE, required: false },
    { name: 'type', pattern: PATTERNS.NAME, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'post', path: '/ops/incidents', action: 'IPM_CREATE', tokenIdentity: 'actor', fields: [
    { name: 'incidentRef', pattern: PATTERNS.KEY, required: true },
    { name: 'title', pattern: PATTERNS.NAME, required: true },
    { name: 'incidentType', pattern: PATTERNS.NAME, required: true },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/ops/incidents/:id', action: 'IPM_GET', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/ops/incidents/:id/calc', action: 'IPM_CALC', tokenIdentity: 'actor', fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'post', path: '/ops/incidents/:id/delete', action: 'IPM_DELETE', tokenIdentity: 'actor', fields: [
    ID,
    { name: 'reason', pattern: PATTERNS.NAME, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
];
