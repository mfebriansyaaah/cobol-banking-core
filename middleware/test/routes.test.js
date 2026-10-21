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
  UNLOCK_USER: 'actor',
  ADMIN_RESET_MFA: 'actor',
  REVERSE_TRANSFER: 'actor',
  TX_STATUS: 'actor',
  MFA_ENROLL_BEGIN: 'actor',
  MFA_ENROLL_CONFIRM: 'actor',
  MFA_DISABLE: 'actor',
  LIST_SESSIONS: 'actor',
  LIST_AUDIT: 'actor',
  REVOKE_USER_SESSION: 'actor',
  REVOKE_ALL_SESSIONS: 'actor',
  TRANSFER: 'from',
  GL_ACCOUNT_LIST: 'actor',
  GL_ACCOUNT_CREATE: 'actor',
  GL_JOURNAL_POST: 'actor',
  GL_JOURNAL_POST_ML: 'actor',
  GL_TRIAL_BALANCE: 'actor',
  GL_PERIOD_OPEN: 'actor',
  GL_PERIOD_CLOSE: 'actor',
  GL_PERIOD_LIST: 'actor',
  BATCH_JOB_CREATE: 'actor',
  BATCH_JOB_LIST: 'actor',
  BATCH_JOB_UPDATE: 'actor',
  BATCH_STEP_CREATE: 'actor',
  BATCH_STEP_LIST: 'actor',
  BATCH_RUN_START: 'actor',
  BATCH_RUN_STATUS: 'actor',
  BATCH_RUN_LIST: 'actor',
  BATCH_RUN_CHECKPOINT: 'actor',
  BATCH_RUN_COMPLETE: 'actor',
  BATCH_RUN_FAIL: 'actor',
  BATCH_RUN_RETRY: 'actor',
  BATCH_RUN_STEP: 'actor',
  BATCH_CONTROL_TOTAL: 'actor',
  BATCH_EOD_START: 'actor',
  RPT_TEMPLATE_CREATE: 'actor',
  RPT_TEMPLATE_LIST: 'actor',
  RPT_TEMPLATE_GET: 'actor',
  RPT_COLUMN_CREATE: 'actor',
  RPT_COLUMN_LIST: 'actor',
  RPT_RUN_START: 'actor',
  RPT_RUN_ROW: 'actor',
  RPT_RUN_STATUS: 'actor',
  RPT_RUN_COMPLETE: 'actor',
  RPT_RUN_FAIL: 'actor',
  RPT_RUN_LIST: 'actor',
  RPT_RUN_EXPORT: 'actor',
  IMP_BATCH_CREATE: 'actor',
  IMP_BATCH_LIST: 'actor',
  IMP_BATCH_GET: 'actor',
  IMP_ROW_STAGE: 'actor',
  IMP_BATCH_VALIDATE: 'actor',
  IMP_ROW_CORRECT: 'actor',
  IMP_ERROR_LIST: 'actor',
  IMP_BATCH_POST: 'actor',
  IMP_BATCH_FAIL: 'actor',
  IMP_BATCH_EXPORT: 'actor',
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

test('privileged admin writes require a step-up proof', () => {
  const guarded = ['CHANGE_ROLE', 'SET_USER_STATUS', 'UNLOCK_USER', 'ADMIN_RESET_MFA', 'ARCHIVE_AUDIT', 'REVERSE_TRANSFER'];
  for (const action of guarded) {
    const routes = ROUTES.filter((r) => r.action === action);
    assert.ok(routes.length > 0, `${action} is exposed by a route`);
    for (const route of routes) {
      assert.equal(route.stepUp, true, `${route.method} ${route.path} (${action}) must require step-up`);
    }
  }
});
