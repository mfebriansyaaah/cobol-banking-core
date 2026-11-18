// Structure pin for the Phase 2 wallet paragraph split. No database needed.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { paragraphLengths } from '../check_cobol_paragraphs.mjs';

const read = (p) => readFileSync(p, 'utf8');

test('wallet transfer orchestrates named helpers instead of one 379-line paragraph', () => {
  const src = read('cobol/src/wallet_transfer_core.cob');
  for (const p of [
    'CHECK-ACCOUNT-PINS',
    'PREPARE-TRANSFER-INTENT',
    'CHECK-CURRENCY-PRECISION',
    'LOAD-TRANSFER-CONTEXT',
    'MAP-TRANSFER-FAILURE',
  ]) {
    assert.match(src, new RegExp(`^\\s{8}${p}\\.$`, 'm'), `${p} paragraph exists`);
    assert.match(src, new RegExp(`PERFORM ${p}`), `${p} is called`);
  }
  const main = paragraphLengths(src).find((p) => p.name === 'TRANSFER-LOGIC');
  assert.ok(main && main.lines <= 220, 'TRANSFER-LOGIC stays under the paragraph cap');
});

test('wallet reversal orchestrates named helpers instead of one 370-line paragraph', () => {
  const src = read('cobol/src/wallet_reversal_core.cob');
  for (const p of ['RESOLVE-REVERSAL-SENDER', 'LOAD-REVERSAL-LEGS', 'BEGIN-AND-LOCK-REVERSAL', 'POST-REVERSAL-LEGS']) {
    assert.match(src, new RegExp(`^\\s{8}${p}\\.$`, 'm'), `${p} paragraph exists`);
    assert.match(src, new RegExp(`PERFORM ${p}`), `${p} is called`);
  }
  const main = paragraphLengths(src).find((p) => p.name === 'REVERSE-TRANSFER-LOGIC');
  assert.ok(main && main.lines <= 220, 'REVERSE-TRANSFER-LOGIC stays under the paragraph cap');
});
