import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const REF_EXT_ROUTES = [
  {
    method: 'post', path: '/ref/ext/translations', action: 'RX_TRANSLATION_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.RX_TYPE, required: true },
      { name: 'code', pattern: PATTERNS.RX_CODE, required: true },
      { name: 'locale', pattern: PATTERNS.RX_LOCALE, required: true },
      { name: 'label', pattern: PATTERNS.RX_LABEL, required: true },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/ref/ext/translations/:type/:code', action: 'RX_TRANSLATION_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.RX_TYPE, required: true },
      { name: 'code', pattern: PATTERNS.RX_CODE, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/ref/ext/hierarchy', action: 'RX_HIERARCHY_ADD',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.RX_TYPE, required: true },
      { name: 'parent', pattern: PATTERNS.RX_CODE, required: true },
      { name: 'child', pattern: PATTERNS.RX_CODE, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/ref/ext/hierarchy/:type', action: 'RX_HIERARCHY_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.RX_TYPE, required: true },
      { name: 'parent', pattern: PATTERNS.RX_CODE, required: false },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'delete', path: '/ref/ext/hierarchy/:type/:parent/:child', action: 'RX_HIERARCHY_REMOVE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.RX_TYPE, required: true },
      { name: 'parent', pattern: PATTERNS.RX_CODE, required: true },
      { name: 'child', pattern: PATTERNS.RX_CODE, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/ref/ext/values/:type/:code/asof', action: 'RX_VALUE_GET_ASOF',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.RX_TYPE, required: true },
      { name: 'code', pattern: PATTERNS.RX_CODE, required: true },
      { name: 'date', pattern: PATTERNS.DATE, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/ref/ext/values/:type/:code/clone', action: 'RX_VALUE_CLONE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.RX_TYPE, required: true },
      { name: 'code', pattern: PATTERNS.RX_CODE, required: true },
      { name: 'newCode', pattern: PATTERNS.RX_CODE, required: true },
      { name: 'label', pattern: PATTERNS.RX_LABEL, required: true },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/ref/ext/export/:type', action: 'RX_EXPORT',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.RX_TYPE, required: true },
      { name: 'format', pattern: PATTERNS.RX_FORMAT, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
];
