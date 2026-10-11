// Translate a COBOL result line ("SUCCESS|..." / "ERROR|<code>|...") into an
// HTTP status and a JSON body. No business logic lives here.

const ERROR_STATUS = {
  MISSING_ACTION: 400,
  INVALID_ACTION: 400,
  INVALID_CODE: 400,
  WEAK_PASSWORD: 400,
  EMAIL_EXISTS: 400,
  INVALID_ROLE: 400,
  NOT_FOUND: 404,
  ACCOUNT_NOT_FOUND: 404,
  TARGET_NOT_FOUND: 404,
  INVALID_CREDENTIALS: 401,
  UNVERIFIED: 403,
  FORBIDDEN: 403,
  ROLE_DENIED: 403,
  INSUFFICIENT_FUNDS: 409,
  DB_INIT_FAILED: 500,
  DB_CONN_FAILED: 500,
  QUERY_FAILED: 500,
  SIGNUP_FAILED: 500,
  VERIFY_FAILED: 500,
  EMAIL_CHANGE_FAILED: 500,
  ROLE_CHANGE_FAILED: 500,
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
  return { ok: false, code: 'MALFORMED', fields: parts };
}

export function toHttp(raw) {
  const parsed = parse(raw);
  if (parsed.ok) {
    return { status: 200, body: { data: parsed.fields } };
  }
  const status = ERROR_STATUS[parsed.code] ?? 500;
  return { status, body: { error: parsed.code, detail: parsed.fields } };
}
