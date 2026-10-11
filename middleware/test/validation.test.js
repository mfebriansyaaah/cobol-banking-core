import { test } from 'node:test';
import assert from 'node:assert/strict';
import { assertLineLength, MAX_INPUT_LINE, ValidationError } from '../src/validation.js';

test('a line within the record passes and is returned', () => {
  const line = assertLineLength('AUTH_LOGIN', ['a@b.com', 'secret']);
  assert.equal(line, 'AUTH_LOGIN|a@b.com|secret');
});

test('a line under the cap is accepted', () => {
  assert.doesNotThrow(() => assertLineLength('X', ['a'.repeat(400)]));
});

test('a line over the COBOL record is rejected', () => {
  assert.throws(
    () => assertLineLength('X', ['a'.repeat(MAX_INPUT_LINE)]),
    ValidationError,
  );
});

test('COBOL-escaped fields accept metacharacters but not the pipe/newline', async () => {
  const { check, PATTERNS } = await import('../src/validation.js');
  // password/name are escaped by COBOL, so metacharacters are allowed...
  for (const ok of ["o'brien", 'a\\b', 'x; y']) {
    assert.doesNotThrow(() => check(ok, PATTERNS.PASSWORD, 'password'));
  }
  assert.doesNotThrow(() => check("O'Brien", PATTERNS.NAME, 'name'));
  // ...but the input-line format characters are always rejected.
  assert.throws(() => check('a|b', PATTERNS.PASSWORD, 'password'), ValidationError);
  assert.throws(() => check('a\nb', PATTERNS.PASSWORD, 'password'), ValidationError);
});
