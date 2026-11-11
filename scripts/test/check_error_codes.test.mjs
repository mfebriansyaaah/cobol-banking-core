// Unit tests for scripts/check_error_codes.mjs (maint-01).
// No database, no build. Pure helpers are imported directly.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { extractCobolCodes, parseRegistry, parseRuntimeMap, checkAll, INTERNAL_CODES } from '../check_error_codes.mjs';

test('extractCobolCodes collects ERROR literals', () => {
  const codes = extractCobolCodes('MOVE "ERROR|OVERPAID" TO X\nIF Y = "ERROR|NO_DATA"\n');
  assert.deepEqual([...codes].sort(), ['NO_DATA', 'OVERPAID']);
});

test('parseRegistry reads code/status pairs and rejects status-less entries', () => {
  const reg = parseRegistry('codes:\n  OVERPAID: { status: 409, origin: cobol }\n');
  assert.deepEqual([...reg.entries()], [['OVERPAID', 409]]);
  assert.throws(() => parseRegistry('  BROKEN: { origin: cobol }\n'), /without status/);
});

test('parseRuntimeMap reads ERROR_STATUS entries', () => {
  const map = parseRuntimeMap('export const ERROR_STATUS = {\n  OVERPAID: 409,\n  FOO: 400\n};\n');
  assert.deepEqual(
    [...map.entries()].sort(([a], [b]) => (a < b ? -1 : 1)),
    [
      ['FOO', 400],
      ['OVERPAID', 409],
    ],
  );
});

test('internal codes are exempt from registration', () => {
  assert.ok(INTERNAL_CODES.has('NO_DATA'));
  const errors = checkAll({
    cobol: new Set(['NO_DATA']),
    registry: new Map(),
    runtime: new Map(),
  });
  assert.deepEqual(errors, []);
});

test('unregistered COBOL code fails', () => {
  const errors = checkAll({
    cobol: new Set(['OVERPAID']),
    registry: new Map(),
    runtime: new Map(),
  });
  assert.equal(errors.length, 1);
  assert.match(errors[0], /unregistered COBOL code: ERROR\|OVERPAID/);
});

test('status mismatch between registry and runtime fails', () => {
  const errors = checkAll({
    cobol: new Set(['OVERPAID']),
    registry: new Map([['OVERPAID', 409]]),
    runtime: new Map([['OVERPAID', 500]]),
  });
  assert.equal(errors.length, 1);
  assert.match(errors[0], /status mismatch for OVERPAID/);
});

test('runtime code missing from registry fails', () => {
  const errors = checkAll({
    cobol: new Set(),
    registry: new Map(),
    runtime: new Map([['BREACHED_PASSWORD', 400]]),
  });
  assert.equal(errors.length, 1);
  assert.match(errors[0], /runtime code missing from registry/);
});

test('fully consistent triple passes', () => {
  const errors = checkAll({
    cobol: new Set(['OVERPAID', 'NO_DATA']),
    registry: new Map([['OVERPAID', 409]]),
    runtime: new Map([['OVERPAID', 409]]),
  });
  assert.deepEqual(errors, []);
});
