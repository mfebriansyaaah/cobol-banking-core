// Unit tests for the COBOL paragraph-length gate.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MAX_LINES, paragraphLengths } from '../check_cobol_paragraphs.mjs';

test('counts body lines per paragraph and ignores comments/blank lines', () => {
  const src = [
    '       PROCEDURE DIVISION.',
    '       MAIN-LOGIC.',
    '           MOVE 1 TO X',
    '           *> comment',
    '',
    '           MOVE 2 TO Y',
    '       ACTION_FOO.',
    '           MOVE 3 TO Z',
  ].join('\n');
  assert.deepEqual(paragraphLengths(src), [
    { name: 'MAIN-LOGIC', lines: 2 },
    { name: 'ACTION_FOO', lines: 1 },
  ]);
});

test('the cap is explicit', () => {
  assert.equal(MAX_LINES, 220);
});
