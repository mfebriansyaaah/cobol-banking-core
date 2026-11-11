import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const ID = { name: 'id', pattern: PATTERNS.INT, required: true };

// Domain loyalty API (LOY_CREATE/ACTIVATE/ENROLL/EARN/REDEEM/EXPIRE/ADJUST
// + reads). Lives under /loyalty/* to avoid shadowing the legacy
// /loyalty-programs/*, /rewards-management/*, /points-redemption/* and
// /cashback/* routes, which are kept for backward compat.
export const LOY_ROUTES = [
  {
    method: 'post',
    path: '/loyalty/programs',
    action: 'LOY_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'programCode', pattern: PATTERNS.KEY, required: true },
      { name: 'name', pattern: PATTERNS.NAME, required: true },
      { name: 'rateSpec', pattern: PATTERNS.RPT_PARAMS, required: true },
      { name: 'dateSpec', pattern: PATTERNS.RPT_PARAMS, required: false },
      { name: 'programType', pattern: PATTERNS.NAME, required: true },
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/loyalty/programs/:id/activate',
    action: 'LOY_ACTIVATE',
    tokenIdentity: 'actor',
    fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/loyalty/programs',
    action: 'LOY_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'status', pattern: PATTERNS.LOY_LIST_STATUS, required: false },
      BLANK,
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/loyalty/members',
    action: 'LOY_ENROLL',
    tokenIdentity: 'actor',
    fields: [
      { name: 'programId', pattern: PATTERNS.INT, required: true },
      { name: 'customerRef', pattern: PATTERNS.KEY, required: true },
      { name: 'tier', pattern: PATTERNS.NAME, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/loyalty/members/:id',
    action: 'LOY_GET',
    tokenIdentity: 'actor',
    fields: [ID, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/loyalty/earn',
    action: 'LOY_EARN',
    tokenIdentity: 'actor',
    fields: [
      { name: 'memberId', pattern: PATTERNS.INT, required: true },
      { name: 'sourceType', pattern: PATTERNS.NAME, required: true },
      { name: 'sourceRef', pattern: PATTERNS.KEY, required: true },
      { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
      { name: 'expiresAt', pattern: PATTERNS.DATE, required: false },
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/loyalty/redeem',
    action: 'LOY_REDEEM',
    tokenIdentity: 'actor',
    fields: [
      { name: 'memberId', pattern: PATTERNS.INT, required: true },
      { name: 'points', pattern: PATTERNS.AMOUNT, required: true },
      { name: 'rewardCode', pattern: PATTERNS.KEY, required: true },
      { name: 'glJournalId', pattern: PATTERNS.INT, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/loyalty/expire',
    action: 'LOY_EXPIRE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'memberId', pattern: PATTERNS.INT, required: true },
      { name: 'asOf', pattern: PATTERNS.DATE, required: true },
      BLANK,
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  // Signed delta (e.g. "-30"): AMOUNT is unsigned-only, so RPT_PARAMS carries
  // the value; COBOL NUMVAL parses the sign and rejects zero/non-numeric.
  {
    method: 'post',
    path: '/loyalty/adjust',
    action: 'LOY_ADJUST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'memberId', pattern: PATTERNS.INT, required: true },
      { name: 'delta', pattern: PATTERNS.RPT_PARAMS, required: true },
      { name: 'reason', pattern: PATTERNS.NAME, required: true },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'post',
    path: '/loyalty/validate',
    action: 'LOY_VALIDATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'programId', pattern: PATTERNS.INT, required: true },
      { name: 'amount', pattern: PATTERNS.AMOUNT, required: true },
      BLANK,
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/loyalty/summary',
    action: 'LOY_SUMMARY',
    tokenIdentity: 'actor',
    fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/loyalty/audit',
    action: 'LOY_AUDIT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'memberId', pattern: PATTERNS.INT, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
];
