import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const NOTIFICATION_ROUTES = [
  {
    method: 'post', path: '/notifications/templates', action: 'NTF_TEMPLATE_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      { name: 'purpose', pattern: PATTERNS.NTF_PURPOSE, required: true },
      { name: 'channel', pattern: PATTERNS.NTF_CHANNEL, required: true },
      { name: 'subject', pattern: PATTERNS.NTF_TEXT, required: true },
      { name: 'body', pattern: PATTERNS.NTF_TEXT, required: true },
      ACTOR,
    ],
  },
  {
    method: 'get', path: '/notifications/templates', action: 'NTF_TEMPLATE_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      { name: 'purpose', pattern: PATTERNS.NTF_PURPOSE, required: false },
      { name: 'channel', pattern: PATTERNS.NTF_CHANNEL, required: false },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/notifications/templates/:code', action: 'NTF_TEMPLATE_GET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'delete', path: '/notifications/templates/:code', action: 'NTF_TEMPLATE_DELETE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: true },
      BLANK, BLANK, BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/notifications/preferences', action: 'NTF_PREF_SET',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'purpose', pattern: PATTERNS.NTF_PURPOSE, required: true },
      { name: 'channel', pattern: PATTERNS.NTF_CHANNEL, required: true },
      { name: 'enabled', pattern: PATTERNS.FLAG, required: true },
      BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/notifications/preferences/:email', action: 'NTF_PREF_LIST',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'limit', pattern: PATTERNS.LIMIT, required: false },
      { name: 'offset', pattern: PATTERNS.INT, required: false },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'get', path: '/notifications/preferences/:email/check', action: 'NTF_PREF_CHECK',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'purpose', pattern: PATTERNS.NTF_PURPOSE, required: true },
      { name: 'channel', pattern: PATTERNS.NTF_CHANNEL, required: true },
      BLANK, BLANK, ACTOR,
    ],
  },
  {
    method: 'post', path: '/notifications/send', action: 'NTF_SEND',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'purpose', pattern: PATTERNS.NTF_PURPOSE, required: true },
      { name: 'code', pattern: PATTERNS.BATCH_CODE, required: false },
      { name: 'detail', pattern: PATTERNS.NTF_TEXT, required: false },
      BLANK, ACTOR,
    ],
  },
];
