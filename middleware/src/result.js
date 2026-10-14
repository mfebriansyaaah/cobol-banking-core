// Translate a COBOL result line ("SUCCESS|..." / "ERROR|<code>|...") into an
// HTTP status and a JSON body. No business logic lives here.

const ERROR_STATUS = {
  MISSING_ACTION: 400,
  INVALID_ACTION: 400,
  INVALID_CODE: 400,
  WEAK_PASSWORD: 400,
  EMAIL_EXISTS: 400,
  INVALID_ROLE: 400,
  INVALID_AMOUNT: 400,
  LIMIT_EXCEEDED: 400,
  DAILY_LIMIT_EXCEEDED: 400,
  CURRENCY_MISMATCH: 400,
  RATE_NOT_FOUND: 400,
  INVALID_INPUT: 400,
  NOT_FOUND: 404,
  ACCOUNT_NOT_FOUND: 404,
  TARGET_NOT_FOUND: 404,
  INVALID_CREDENTIALS: 401,
  MFA_REQUIRED: 401,
  INVALID_MFA: 401,
  SESSION_NOT_FOUND: 401,
  SESSION_EXPIRED: 401,
  SESSION_REUSED: 401,
  TOKEN_REVOKED: 401,
  UNVERIFIED: 403,
  FORBIDDEN: 403,
  ROLE_DENIED: 403,
  ACCOUNT_LOCKED: 423,
  INSUFFICIENT_FUNDS: 409,
  ACCOUNT_FROZEN: 409,
  ACCOUNT_CLOSED: 409,
  CURRENCY_INACTIVE: 409,
  TRANSFER_IN_PROGRESS: 409,
  IDEMPOTENCY_CONFLICT: 409,
  SELF_TRANSFER: 400,
  UNKNOWN_TRANSACTION: 404,
  ALREADY_REVERSED: 409,
  MFA_ALREADY_ENABLED: 409,
  MFA_NOT_ENABLED: 400,
  DB_DOWN: 503,
  MISMATCH: 409,
  DB_INIT_FAILED: 500,
  DB_CONN_FAILED: 500,
  QUERY_FAILED: 500,
  DB_ERROR: 500,
  SIGNUP_FAILED: 500,
  VERIFY_FAILED: 500,
  EMAIL_CHANGE_FAILED: 500,
  ROLE_CHANGE_FAILED: 500,
  AUDIT_ARCHIVE_FAILED: 500,
  REVERSAL_FAILED: 500,
  RESET_FAILED: 500,
  PASSWORD_CHANGE_FAILED: 500,
  RESEND_FAILED: 500,
  MFA_ENROLL_FAILED: 500,
  MFA_DISABLE_FAILED: 500,
  SESSION_CHECK_FAILED: 500,
  SESSION_REVOKE_FAILED: 500,
  SESSION_STORE_FAILED: 500,
  SESSION_LIST_FAILED: 500,
  SESSIONS_REVOKE_FAILED: 500,
  TOKEN_CHECK_FAILED: 500,
  TOKEN_REVOKE_FAILED: 500,
  BEGIN_FAILED: 500,
  COMMIT_FAILED: 500,
  ROLLBACK_FAILED: 500,
  NO_TRANSACTION: 500,
  STMT_INIT_FAILED: 500,
  PREPARE_FAILED: 500,
  BIND_FAILED: 500,
  EXEC_FAILED: 500,
  RESULT_BIND_FAILED: 500,
};

export function parse(raw) {
  const parts = String(raw ?? '').split('|');
  const kind = parts[0];
  if (kind === 'SUCCESS') {
    return { ok: true, code: parts[1] ?? '', fields: parts.slice(1) };
  }
  if (kind === 'ERROR') {
    return { ok: false, code: parts[1] ?? '', fields: parts.slice(2) };
  }
  // Some actions return a bare value (e.g. GET_USER "1|email", CHECK_BALANCE "1000.00").
  return { ok: true, code: 'OK', fields: parts };
}

export function toHttp(raw) {
  const parsed = parse(raw);
  if (parsed.ok) {
    return { status: 200, body: { data: parsed.fields } };
  }
  const status = ERROR_STATUS[parsed.code] ?? 500;
  return { status, body: { error: parsed.code, detail: parsed.fields } };
}
