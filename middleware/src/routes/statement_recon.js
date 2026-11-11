import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const STATEMENT_RECON_ROUTES = [
  {
    method: 'post',
    path: '/statements/recon',
    action: 'SRC_START',
    tokenIdentity: 'actor',
    fields: [{ name: 'statementRunId', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/statements/recon',
    action: 'SRC_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'status', pattern: PATTERNS.RPT_STATUS, required: false },
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/statements/recon/:id',
    action: 'SRC_GET',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/statements/recon/:id/match',
    action: 'SRC_MATCH',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/statements/recon/:id/finish',
    action: 'SRC_FINISH',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/statements/recon/:id/retry',
    action: 'SRC_RETRY',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/statements/recon/:id/items',
    action: 'SRC_ITEMS',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'status', pattern: PATTERNS.SRC_STATUS, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/statements/recon/:id/export',
    action: 'SRC_EXPORT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'format', pattern: PATTERNS.RPT_FORMAT, required: false },
      BLANK,
      BLANK,
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/statements/:statementRunId/recon-summary',
    action: 'SRC_SUMMARY',
    tokenIdentity: 'actor',
    fields: [{ name: 'statementRunId', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
];
