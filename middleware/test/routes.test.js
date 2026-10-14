// Guard: routes whose COBOL action authorizes by identity must fill that field
// from the verified token, never the request body. Covers admin actions,
// self-or-admin reads, the email-change flow, and the transfer sender.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ROUTES } from '../src/app.js';

const TOKEN_IDENTITY = {
  CHANGE_ROLE: 'actor',
  ARCHIVE_AUDIT: 'actor',
  CHANGE_PASSWORD: 'actor',
  RECONCILE: 'actor',
  CHECK_ROLE: 'actor',
  GET_USER: 'actor',
  CHECK_BALANCE: 'actor',
  GET_DASHBOARD: 'actor',
  LIST_USERS: 'actor',
  REQ_EMAIL_CHANGE: 'actor',
  CONFIRM_EMAIL_CHANGE: 'actor',
  UPDATE_PROFILE: 'actor',
  DEACTIVATE_ACCOUNT: 'actor',
  SET_USER_STATUS: 'actor',
  REVERSE_TRANSFER: 'actor',
  TX_STATUS: 'actor',
  MFA_ENROLL_BEGIN: 'actor',
  MFA_ENROLL_CONFIRM: 'actor',
  MFA_DISABLE: 'actor',
  LIST_SESSIONS: 'actor',
  REVOKE_USER_SESSION: 'actor',
  REVOKE_ALL_SESSIONS: 'actor',
  TRANSFER: 'from',
};

test('every identity-authorized action takes its identity from the token', () => {
  for (const [action, field] of Object.entries(TOKEN_IDENTITY)) {
    const routes = ROUTES.filter((r) => r.action === action);
    assert.ok(routes.length > 0, `${action} is exposed by a route`);
    for (const route of routes) {
      assert.equal(route.tokenIdentity, field, `${route.method} ${route.path} (${action}) must set tokenIdentity '${field}'`);
    }
  }
});
