// Whitelist validation. Every parameter that reaches COBOL must match a strict
// regex with no pipe or newline, so it cannot break out of the input line or
// inject a shell argument.

const EMAIL = /^[A-Za-z0-9._%+-]{1,100}@[A-Za-z0-9.-]{1,100}$/;
// No SQL metacharacters: quotes, backtick, semicolon, backslash, or newlines.
const PASSWORD = /^[^|'"`;\\\n\r]{1,100}$/;
const NAME = /^[A-Za-z0-9 .-]{1,100}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const CODE = /^\d{6}$/;
const ROLE = /^(USER|MANAGER|SUPER_ADMIN)$/;
const AMOUNT = /^(?=.*[1-9])\d{1,13}(\.\d{1,2})?$/;
const INT = /^\d{1,6}$/;
const KEY = /^[A-Za-z0-9._:-]{1,50}$/;

export const PATTERNS = { EMAIL, PASSWORD, NAME, DATE, CODE, ROLE, AMOUNT, INT, KEY };

export class ValidationError extends Error {
  constructor(field) {
    super(`invalid parameter: ${field}`);
    this.field = field;
  }
}

// The COBOL entry reads a single PIC X(500) line. Reject any request whose
// composed `ACTION|p1|p2|p3|p4` line would exceed that record (CODING_STANDARDS 13).
export const MAX_INPUT_LINE = 500;

export function assertLineLength(action, params, max = MAX_INPUT_LINE) {
  const line = [action, ...params].join('|');
  if (line.length > max) {
    const err = new ValidationError('input-line');
    err.reason = 'TOO_LONG';
    throw err;
  }
  return line;
}

/** Validate a value against a named pattern; throw ValidationError on failure. */
export function check(value, pattern, field) {
  const v = value ?? '';
  if (!pattern.test(v)) throw new ValidationError(field);
  return v;
}

/**
 * Build the ordered parameter array for an action, validating each present
 * value. Returns [] (all blanks) for actions with no parameters.
 */
export function buildParams(spec, input) {
  return (spec.fields ?? []).map(({ name, pattern, required }) => {
    const value = input[name];
    if (value === undefined || value === '') {
      if (required) throw new ValidationError(name);
      return '';
    }
    return check(String(value), pattern, name);
  });
}
