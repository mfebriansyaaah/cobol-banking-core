// Dispatch paramMode pins (audit P2-11): CALL arity travels with the slot,
// not with a hardcoded program-name branch in main_logic.cob.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseDispatchTable } from '../lib/dispatch_table.mjs';

const ACTIONS = JSON.parse(readFileSync(new URL('../../manifest/actions.json', import.meta.url), 'utf8'));
const COPYBOOK = readFileSync(new URL('../../cobol/copy/dispatch_table.cpy', import.meta.url), 'utf8');
const MAIN_LOGIC = readFileSync(new URL('../../cobol/src/main_logic.cob', import.meta.url), 'utf8');

test('registry assigns mode 1 to user_core, 3 to deposit_core, 2 otherwise', () => {
  assert.ok(ACTIONS.dispatch.length > 0, 'registry has dispatch entries');
  for (const e of ACTIONS.dispatch) {
    const want = e.program === 'user_core' ? 1 : e.program === 'deposit_core' ? 3 : 2;
    assert.equal(e.paramMode, want, `slot ${e.slot} (${e.program})`);
  }
  assert.ok(
    ACTIONS.dispatch.some((e) => e.paramMode === 1),
    'mode 1 present',
  );
  assert.ok(
    ACTIONS.dispatch.some((e) => e.paramMode === 3),
    'mode 3 present',
  );
});

test('copybook carries one D-PARAM-MODE per slot', () => {
  const modes = [...COPYBOOK.matchAll(/MOVE (\d+) TO D-PARAM-MODE\((\d+)\)\./g)];
  assert.equal(modes.length, ACTIONS.dispatch.length, 'one mode line per slot');
});

test('dispatcher switches on mode, not on program names', () => {
  assert.doesNotMatch(MAIN_LOGIC, /IF D-PROGRAM\(DISPATCH-IDX\) = "user_core"/);
  assert.doesNotMatch(MAIN_LOGIC, /IF D-PROGRAM\(DISPATCH-IDX\) = "deposit_core"/);
  assert.match(MAIN_LOGIC, /EVALUATE D-PARAM-MODE\(DISPATCH-IDX\)/);
});

test('parser defaults missing modes to 6-param shape', () => {
  const src = [
    '       01 CMD-ACTION PIC X(20).',
    '       01 DISPATCH-TABLE.',
    '           MOVE "AAA_" TO D-PREFIX(1).',
    '           MOVE 4 TO D-PREFIX-LEN(1).',
    '           MOVE "aaa_core" TO D-PROGRAM(1).',
    '',
  ].join('\n');
  const { entries, problems } = parseDispatchTable(src);
  assert.deepEqual(problems, []);
  assert.equal(entries.length, 1);
  assert.equal(entries[0].paramMode, 2);
});
