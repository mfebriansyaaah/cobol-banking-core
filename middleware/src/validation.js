// Whitelist validation. Every parameter that reaches COBOL must match a strict
// regex with no pipe or newline, so it cannot break out of the input line or
// inject a shell argument.

const EMAIL = /^[A-Za-z0-9._%+-]{1,100}@[A-Za-z0-9.-]{1,100}$/;
const PASSWORD = /^[^|\n\r]{1,100}$/;
const NAME = /^[A-Za-z0-9 .'-]{1,100}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const CODE = /^\d{6}$/;
const ROLE = /^(USER|MANAGER|SUPER_ADMIN)$/;
const AMOUNT = /^\d{1,13}(\.\d{1,2})?$/;

export const PATTERNS = { EMAIL, PASSWORD, NAME, DATE, CODE, ROLE, AMOUNT };

export class ValidationError extends Error {
  constructor(field) {
    super(`invalid parameter: ${field}`);
    this.field = field;
  }
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
