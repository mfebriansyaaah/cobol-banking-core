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
  assert.throws(() => assertLineLength('X', ['a'.repeat(MAX_INPUT_LINE)]), ValidationError);
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

test('nameless BLANK slots can never be filled from client input', async () => {
  const { buildParams, PATTERNS } = await import('../src/validation.js');
  const BLANK = { name: '', pattern: PATTERNS.PASSWORD, required: false };
  const spec = {
    fields: [
      { name: 'email', pattern: PATTERNS.EMAIL, required: true },
      BLANK,
      { name: 'actor', pattern: PATTERNS.EMAIL, required: true },
      BLANK,
    ],
  };
  // A body key of "" must not reach any positional slot.
  assert.deepEqual(buildParams(spec, { email: 'a@b.com', actor: 'a@b.com', '': 'INJECTED' }), [
    'a@b.com',
    '',
    'a@b.com',
    '',
  ]);
  assert.deepEqual(buildParams(spec, { email: 'a@b.com', actor: 'a@b.com' }), ['a@b.com', '', 'a@b.com', '']);
});

test('list status filters use domain enums, never the 6-digit code pattern', async () => {
  const { ALL_ROUTES } = await import('../src/routes/index.js');
  const { PATTERNS } = await import('../src/validation.js');
  const bad = ALL_ROUTES.filter((r) =>
    (r.fields || []).some((f) => f.name === 'status' && f.pattern === PATTERNS.CODE),
  );
  assert.deepEqual(
    bad.map((r) => r.action),
    [],
    'status filters must use domain status enums',
  );
  // Spot checks: template and specialty domains accept their COBOL values.
  assert.ok(PATTERNS.LIST_STATUS.test('ACTIVE'));
  assert.ok(!PATTERNS.LIST_STATUS.test('123456'));
  assert.ok(PATTERNS.PMC_LIST_STATUS.test('SETTLED'));
  assert.ok(PATTERNS.TRL_LIST_STATUS.test('PROJECTED'));
  assert.ok(PATTERNS.CHB_CASE_STATUS.test('EVIDENCE_REQUIRED'));
  assert.ok(PATTERNS.LOY_LIST_STATUS.test('DRAFT'));
});
