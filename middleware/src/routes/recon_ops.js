import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const RECON_OPS_ROUTES = [
  {
    method: 'post', path: '/recon/rules', action: 'RCP_RULE_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'rule', pattern: PATTERNS.RPT_CODE, required: true },
      { name: 'owner', pattern: PATTERNS.EMAIL, required: true },
      { name: 'statusFilter', pattern: PATTERNS.RCP_STATUS_FILTER, required: true },
      { name: 'minAgeHours', pattern: PATTERNS.INT, required: true },
      { name: 'options', pattern: PATTERNS.RCP_RULE_SPEC, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/recon/rules', action: 'RCP_RULE_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'statusFilter', pattern: PATTERNS.RCP_STATUS_FILTER, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/recon/rules/:rule', action: 'RCP_RULE_GET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'rule', pattern: PATTERNS.RPT_CODE, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'delete', path: '/recon/rules/:rule', action: 'RCP_RULE_DELETE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'rule', pattern: PATTERNS.RPT_CODE, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/recon/rules/:rule/preview', action: 'RCP_RULE_PREVIEW',
    tokenIdentity: 'actor',
    fields: [
      { name: 'rule', pattern: PATTERNS.RPT_CODE, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/recon/auto-assign', action: 'RCP_AUTO_ASSIGN',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'dryRun', pattern: PATTERNS.FLAG, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/recon/findings/:id/assign', action: 'RCP_MANUAL_ASSIGN',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'owner', pattern: PATTERNS.EMAIL, required: true },
      { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/recon/findings/:id/unassign', action: 'RCP_UNASSIGN',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'note', pattern: PATTERNS.BATCH_DETAIL, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/recon/escalate-overdue', action: 'RCP_ESCALATE_OVERDUE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'ageHours', pattern: PATTERNS.INT, required: true },
      { name: 'manager', pattern: PATTERNS.EMAIL, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/recon/workload', action: 'RCP_WORKLOAD',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get', path: '/recon/findings/:id/assignment-history', action: 'RCP_HISTORY',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
];
