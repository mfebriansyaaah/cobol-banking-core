import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const REF_ENGINE_ROUTES = [
  {
    method: 'get', path: '/reference-engine/types', action: 'RFE_TYPE_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reference-engine/types', action: 'RFE_TYPE_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.REF_TYPE, required: true },
      { name: 'label', pattern: PATTERNS.REF_LABEL, required: true },
      { name: 'description', pattern: PATTERNS.REF_ATTRIBUTES, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reference-engine/values', action: 'RFE_VALUE_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.REF_TYPE, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reference-engine/values', action: 'RFE_VALUE_CREATE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.REF_TYPE, required: true },
      { name: 'code', pattern: PATTERNS.REF_VALUE_CODE, required: true },
      { name: 'label', pattern: PATTERNS.REF_LABEL, required: true },
      { name: 'attributes', pattern: PATTERNS.REF_ATTRIBUTES, required: false },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reference-engine/values/:type/:code', action: 'RFE_VALUE_GET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.REF_TYPE, required: true },
      { name: 'code', pattern: PATTERNS.REF_VALUE_CODE, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/reference-engine/values/:type/:code/history', action: 'RFE_VALUE_HIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.REF_TYPE, required: true },
      { name: 'code', pattern: PATTERNS.REF_VALUE_CODE, required: true },
      BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reference-engine/values/:type/:code/approve', action: 'RFE_VALUE_APPROVE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.REF_TYPE, required: true },
      { name: 'code', pattern: PATTERNS.REF_VALUE_CODE, required: true },
      { name: 'version', pattern: PATTERNS.REF_VERSION, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/reference-engine/values/:type/:code/retire', action: 'RFE_VALUE_RETIRE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'type', pattern: PATTERNS.REF_TYPE, required: true },
      { name: 'code', pattern: PATTERNS.REF_VALUE_CODE, required: true },
      { name: 'reason', pattern: PATTERNS.REASON, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
];
