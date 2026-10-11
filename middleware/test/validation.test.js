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
