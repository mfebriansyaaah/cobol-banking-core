import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
export const IMPORT_RECON_ROUTES = [
  {
    method: 'post',
    path: '/imports/recon',
    action: 'IRC_START',
    tokenIdentity: 'actor',
    fields: [{ name: 'batchCode', pattern: PATTERNS.BATCH_CODE, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/imports/recon',
    action: 'IRC_LIST',
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
    path: '/imports/recon/:id',
    action: 'IRC_GET',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/imports/recon/:id/match',
    action: 'IRC_MATCH',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/imports/recon/:id/finish',
    action: 'IRC_FINISH',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'post',
    path: '/imports/recon/:id/retry',
    action: 'IRC_RETRY',
    tokenIdentity: 'actor',
    fields: [{ name: 'id', pattern: PATTERNS.INT, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
  {
    method: 'get',
    path: '/imports/recon/:id/items',
    action: 'IRC_ITEMS',
    tokenIdentity: 'actor',
    fields: [
      { name: 'id', pattern: PATTERNS.INT, required: true },
      { name: 'status', pattern: PATTERNS.IRC_STATUS, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK,
      ACTOR,
    ],
  },
  {
    method: 'get',
    path: '/imports/recon/:id/export',
    action: 'IRC_EXPORT',
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
    path: '/imports/:code/recon-summary',
    action: 'IRC_SUMMARY',
    tokenIdentity: 'actor',
    fields: [{ name: 'code', pattern: PATTERNS.BATCH_CODE, required: true }, BLANK, BLANK, BLANK, BLANK, ACTOR],
  },
];
