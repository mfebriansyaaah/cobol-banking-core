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

test('SQL metacharacters are rejected in passwords and names', async () => {
  const { check, PATTERNS } = await import('../src/validation.js');
  for (const bad of ["o'brien", 'a\\b', 'x"; DROP', 'tick`']) {
    assert.throws(() => check(bad, PATTERNS.PASSWORD, 'password'), ValidationError);
  }
  for (const bad of ["O'Brien", 'a;b']) {
    assert.throws(() => check(bad, PATTERNS.NAME, 'name'), ValidationError);
  }
  assert.doesNotThrow(() => check('S3cret-pass_OK', PATTERNS.PASSWORD, 'password'));
  assert.doesNotThrow(() => check('Budi Santoso', PATTERNS.NAME, 'name'));
});
