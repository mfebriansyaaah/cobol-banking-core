import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const COMPLIANCE_RETENTION_ROUTES = [
  { method: 'post', path: '/compliance/retention/policies', action: 'CRT_POLICY_SET', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    { name: 'entity', pattern: PATTERNS.CRT_ENTITY, required: true },
    { name: 'days', pattern: PATTERNS.EXP_DAYS, required: true },
    { name: 'enabled', pattern: PATTERNS.FLAG, required: false },
    BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/retention/policies', action: 'CRT_POLICY_LIST', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'delete', path: '/compliance/retention/policies/:code', action: 'CRT_POLICY_DELETE', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'post', path: '/compliance/retention/policies/:code/run', action: 'CRT_RETENTION_RUN', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: true },
    BLANK, BLANK, BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/retention/runs', action: 'CRT_RUN_LIST', tokenIdentity: 'actor', fields: [
    { name: 'code', pattern: PATTERNS.RPT_CODE, required: false },
    { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
    { name: 'offset', pattern: PATTERNS.INT, required: false },
    BLANK, BLANK, ACTOR,
  ] },
  { method: 'get', path: '/compliance/retention/summary', action: 'CRT_SUMMARY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
];
