import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parse, toHttp, ERROR_STATUS } from '../src/result.js';

// The HTTP contract, written out independently of ERROR_STATUS so an
// accidental edit — or a new code added without a status — fails this test.
const EXPECT = {
  400: [
    'MISSING_ACTION', 'INVALID_ACTION', 'INVALID_CODE', 'WEAK_PASSWORD', 'EMAIL_EXISTS',
    'INVALID_ROLE', 'INVALID_AMOUNT', 'LIMIT_EXCEEDED', 'DAILY_LIMIT_EXCEEDED',
    'CURRENCY_MISMATCH', 'RATE_NOT_FOUND', 'INVALID_INPUT', 'SELF_TRANSFER',
    'INVALID_STATUS', 'MFA_NOT_ENABLED',
  ],
  401: [
    'INVALID_CREDENTIALS', 'MFA_REQUIRED', 'MFA_SETUP_REQUIRED', 'INVALID_MFA',
    'SESSION_NOT_FOUND', 'SESSION_EXPIRED', 'SESSION_FAMILY_EXPIRED', 'SESSION_REUSED',
    'TOKEN_REVOKED',
  ],
  403: ['UNVERIFIED', 'FORBIDDEN', 'ROLE_DENIED', 'USER_SUSPENDED', 'USER_CLOSED'],
  404: ['NOT_FOUND', 'ACCOUNT_NOT_FOUND', 'TARGET_NOT_FOUND', 'UNKNOWN_TRANSACTION'],
  409: [
    'INSUFFICIENT_FUNDS', 'ACCOUNT_FROZEN', 'ACCOUNT_CLOSED', 'CURRENCY_INACTIVE',
    'TRANSFER_IN_PROGRESS', 'IDEMPOTENCY_CONFLICT', 'AMBIGUOUS_TRANSACTION',
    'AMBIGUOUS_ACCOUNT', 'LAST_ADMIN', 'ALREADY_REVERSED', 'MFA_ALREADY_ENABLED', 'MISMATCH',
  ],
  423: ['ACCOUNT_LOCKED'],
  500: [
    'DB_INIT_FAILED', 'DB_CONN_FAILED', 'QUERY_FAILED', 'DB_ERROR', 'SIGNUP_FAILED',
    'VERIFY_FAILED', 'EMAIL_CHANGE_FAILED', 'ROLE_CHANGE_FAILED', 'AUDIT_ARCHIVE_FAILED',
    'REVERSAL_FAILED', 'PROFILE_UPDATE_FAILED', 'DEACTIVATE_FAILED', 'STATUS_CHANGE_FAILED',
    'UNLOCK_FAILED', 'MFA_RESET_FAILED', 'RESET_FAILED', 'PASSWORD_CHANGE_FAILED',
    'RESEND_FAILED', 'MFA_ENROLL_FAILED', 'MFA_DISABLE_FAILED', 'SESSION_CHECK_FAILED',
    'SESSION_REVOKE_FAILED', 'SESSION_STORE_FAILED', 'SESSION_LIST_FAILED',
    'SESSIONS_REVOKE_FAILED', 'TOKEN_CHECK_FAILED', 'TOKEN_REVOKE_FAILED',
    'BEGIN_FAILED', 'COMMIT_FAILED', 'ROLLBACK_FAILED', 'NO_TRANSACTION',
    'STMT_INIT_FAILED', 'PREPARE_FAILED', 'BIND_FAILED', 'EXEC_FAILED', 'RESULT_BIND_FAILED',
  ],
  503: ['DB_DOWN', 'DB_BUSY'],
};

test('success maps to 200 with data fields', () => {
  assert.deepEqual(toHttp('SUCCESS|LOGIN_OK'), { status: 200, body: { data: ['LOGIN_OK'] } });
});

test('not-found error maps to 404', () => {
  assert.equal(toHttp('ERROR|ACCOUNT_NOT_FOUND').status, 404);
});

test('locked account maps to 423', () => {
  const r = toHttp('ERROR|ACCOUNT_LOCKED');
  assert.equal(r.status, 423);
  assert.equal(r.body.error, 'ACCOUNT_LOCKED');
});

test('a bare value (no prefix) is treated as success data', () => {
  assert.deepEqual(toHttp('1|sender@test.com'), { status: 200, body: { data: ['1', 'sender@test.com'] } });
  assert.deepEqual(toHttp('1000.00'), { status: 200, body: { data: ['1000.00'] } });
});

test('reconcile mismatch maps to 409 with the offending account(s)', () => {
  const r = toHttp('ERROR|MISMATCH|2|5.00|0.00');
  assert.equal(r.status, 409);
  assert.equal(r.body.error, 'MISMATCH');
  assert.deepEqual(r.body.detail, ['2', '5.00', '0.00']);
});

test('session and token errors map to 401', () => {
  for (const code of ['SESSION_NOT_FOUND', 'SESSION_EXPIRED', 'SESSION_REUSED', 'TOKEN_REVOKED']) {
    assert.equal(toHttp(`ERROR|${code}`).status, 401, code);
  }
});

test('internal failures map to 500', () => {
  for (const code of ['SESSION_CHECK_FAILED', 'SESSION_REVOKE_FAILED', 'TOKEN_REVOKE_FAILED', 'DB_CONN_FAILED', 'PREPARE_FAILED', 'EXEC_FAILED', 'NO_TRANSACTION']) {
    assert.equal(toHttp(`ERROR|${code}`).status, 500, code);
  }
});

test('every error code maps to its documented HTTP status', () => {
  for (const [status, codes] of Object.entries(EXPECT)) {
    for (const code of codes) {
      assert.equal(toHttp(`ERROR|${code}`).status, Number(status), code);
      assert.equal(toHttp(`ERROR|${code}`).body.error, code);
    }
  }

  // The contract above and the implementation must list exactly the same codes,
  // so a new code cannot silently default to 500 (the ?? fallback).
  assert.deepEqual(Object.keys(ERROR_STATUS).sort(), Object.values(EXPECT).flat().sort());
});

test('an unknown error code falls back to 500', () => {
  assert.equal(toHttp('ERROR|SOMETHING_NEW').status, 500);
});
