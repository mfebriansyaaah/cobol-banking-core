// Unit tests for scripts/check_program_signatures.mjs (maint-01).
// No database, no build. Pure helpers are imported directly; the real tree
// is pinned by running the gate itself (like check_txn_callgraph_sizes).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  expectedParams,
  usingParamCount,
  callArity,
  resolveProgram,
  checkRule1,
} from '../check_program_signatures.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

test('expectedParams knows the 4/7-slot exceptions', () => {
  assert.equal(expectedParams('user_core'), 4);
  assert.equal(expectedParams('deposit_core'), 7);
  assert.equal(expectedParams('card_core'), 6);
  assert.equal(expectedParams('anything_else'), 6);
});

test('usingParamCount counts LS-PARAMn in the USING clause', () => {
  assert.equal(usingParamCount('PROCEDURE DIVISION USING A B LS-PARAM1 LS-PARAM2 LS-PARAM3 LS-PARAM4 X.'), 4);
  assert.equal(
    usingParamCount(
      'PROCEDURE DIVISION USING LS-CMD-ACTION LS-PARAM1 LS-PARAM2\n LS-PARAM3 LS-PARAM4 LS-PARAM5 LS-PARAM6 LS-PARAM7\n LS-OUTPUT-BUFFER.',
    ),
    7,
  );
  assert.equal(usingParamCount('PROCEDURE DIVISION USING LS-HASH LS-HLEN.'), null);
});

test('callArity counts CMD-PARAMn on a CALL line', () => {
  assert.equal(callArity('CALL D-PROGRAM USING CMD-ACTION CMD-PARAM1 CMD-PARAM2 CMD-PARAM3 CMD-PARAM4 WS-OUT'), 4);
  assert.equal(callArity('CALL X USING CMD-ACTION CMD-PARAM1 WS-OUT'), 1);
  assert.equal(callArity('CALL X USING FOO BAR'), null);
});

test('resolveProgram picks the longest matching prefix', () => {
  const entries = [
    { prefix: 'LOAN_', program: 'loan_core' },
    { prefix: 'LOAN_DISBURSE', program: 'special_core' },
  ];
  assert.equal(resolveProgram('LOAN_DISBURSE_X', entries), 'special_core');
  assert.equal(resolveProgram('LOAN_GET', entries), 'loan_core');
  assert.equal(resolveProgram('CARD_GET', entries), null);
});

test('checkRule1 fails a named field past the program limit', () => {
  const entries = [{ prefix: 'GET_', program: 'user_core' }];
  const bad = [
    {
      action: 'GET_USER',
      method: 'get',
      path: '/users/:email',
      routeFile: 'user_profile.js',
      fields: [
        { slot: 1, name: 'email' },
        { slot: 2, name: 'actor' },
        { slot: 3, name: '' },
        { slot: 4, name: '' },
        { slot: 5, name: 'sneaky' },
        { slot: 6, name: '' },
      ],
    },
  ];
  const errors = checkRule1(bad, entries);
  assert.equal(errors.length, 1);
  assert.match(errors[0], /sneaky.*slot 5 never reaches user_core \(4 params\)/);
});

test('checkRule1 accepts padding past the limit', () => {
  const entries = [{ prefix: 'GET_', program: 'user_core' }];
  const ok = [
    {
      action: 'GET_USER',
      method: 'get',
      path: '/users/:email',
      routeFile: 'user_profile.js',
      fields: [
        { slot: 1, name: 'email' },
        { slot: 2, name: 'actor' },
        { slot: 3, name: '' },
        { slot: 4, name: '' },
        { slot: 5, name: '' },
        { slot: 6, name: '' },
      ],
    },
  ];
  assert.deepEqual(checkRule1(ok, entries), []);
});

test('gate holds on the real tree', () => {
  const out = execFileSync('node', [path.join(ROOT, 'scripts', 'check_program_signatures.mjs'), ROOT], {
    encoding: 'utf8',
  });
  assert.match(out, /OK: route fields fit program params/);
});
