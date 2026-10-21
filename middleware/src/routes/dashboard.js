import { PATTERNS } from '../validation.js';

const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
const ACTOR = { name: 'actor', pattern: PATTERNS.EMAIL, required: true };
const DATE_RANGE = [
  { name: 'from', pattern: PATTERNS.DATE, required: false },
  { name: 'to', pattern: PATTERNS.DATE, required: false },
  { name: 'currency', pattern: PATTERNS.CURRENCY, required: false },
  BLANK, BLANK, ACTOR,
];

export const DASHBOARD_ROUTES = [
  { method: 'get', path: '/dashboard/overview', action: 'DSH_OVERVIEW', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dashboard/payments', action: 'DSH_PAYMENTS', tokenIdentity: 'actor', fields: DATE_RANGE },
  { method: 'get', path: '/dashboard/recon', action: 'DSH_RECON', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dashboard/disputes', action: 'DSH_DISPUTES', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dashboard/alerts', action: 'DSH_ALERTS', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dashboard/outbox', action: 'DSH_OUTBOX', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dashboard/reports', action: 'DSH_REPORTS', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dashboard/imports', action: 'DSH_IMPORTS', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dashboard/accounts', action: 'DSH_ACCOUNTS', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dashboard/fees', action: 'DSH_FEES', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dashboard/policy', action: 'DSH_POLICY', tokenIdentity: 'actor', fields: [BLANK, BLANK, BLANK, BLANK, BLANK, ACTOR] },
  { method: 'get', path: '/dashboard/cashflow', action: 'DSH_CASHFLOW', tokenIdentity: 'actor', fields: DATE_RANGE },
];
