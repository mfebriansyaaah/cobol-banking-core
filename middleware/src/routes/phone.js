import { PATTERNS } from '../validation.js';
const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };

export const PHONE_ROUTES = [
  // The phone number is normalized and hashed server-side (derivations.js);
  // only the hash is stored. A client-sent phoneHash is overwritten.
  {
    method: 'post',
    path: '/auth/phone/link/begin',
    action: 'OTP_LINK_BEGIN',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'phoneHash', pattern: PATTERNS.REF_VALUE_CODE, required: false },
      BLANK,
      ACTOR,
      BLANK,
      BLANK,
    ],
  },
  {
    method: 'post',
    path: '/auth/phone/link/confirm',
    action: 'OTP_LINK_CONFIRM',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'token', pattern: PATTERNS.KEY, required: true },
      { name: 'chatId', pattern: PATTERNS.KEY, required: true },
      ACTOR,
      BLANK,
      BLANK,
    ],
  },
  {
    method: 'post',
    path: '/auth/phone/otp/issue',
    action: 'OTP_ISSUE',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'channel', pattern: PATTERNS.NAME, required: true },
      { name: 'purpose', pattern: PATTERNS.KEY, required: true },
      ACTOR,
      BLANK,
      BLANK,
    ],
  },
  {
    method: 'post',
    path: '/auth/phone/otp/verify',
    action: 'OTP_VERIFY',
    tokenIdentity: 'actor',
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      { name: 'code', pattern: PATTERNS.CODE, required: true },
      { name: 'purpose', pattern: PATTERNS.KEY, required: true },
      ACTOR,
      BLANK,
      BLANK,
    ],
  },
];
