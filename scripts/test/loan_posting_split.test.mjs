// Loan posting split pins (maint-09). No database, no build.
//
// loan_posting_core.cob owns the pre-transaction resolve+GL-post for
// disburse and repay (LOAN_POST_DISBURSE/REPAY), including the
// claim/delete idempotency helpers. loan_core keeps the action dispatch,
// the auth guards, and the single transaction per action. Universal
// invariants:
//   - the posting module opens no transaction (0 BEGIN/COMMIT/ROLLBACK);
//   - it never calls back into loan_core (acyclic: loan -> posting -> gl);
//   - loan_core no longer holds the moved resolve blocks or the moved
//     CLAIM/DELETE paragraphs;
//   - the call graph records both new edges.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const srcOf = (module) => readFileSync(path.join(SRC, `${module}.cob`), 'utf8');

test('loan_posting_core defines the two posting actions', () => {
  const src = srcOf('loan_posting_core');
  for (const name of ['ACTION-POST-DISBURSE', 'ACTION-POST-REPAY']) {
    assert.match(src, new RegExp(`^ {8}${name}\\.$`, 'm'), `posting module must define ${name}`);
  }
  for (const name of [
    'CLAIM-DISBURSE-REQUEST',
    'DELETE-DISBURSE-REQUEST',
    'CLAIM-REPAY-REQUEST',
    'DELETE-REPAY-REQUEST',
  ]) {
    assert.match(src, new RegExp(`^ {7,8}${name}\\.$`, 'm'), `posting module must own ${name}`);
  }
});

test('loan_posting_core opens no transaction and never calls back', () => {
  const src = srcOf('loan_posting_core');
  assert.doesNotMatch(src, /CALL "SQL_BEGIN"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "SQL_COMMIT"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "SQL_ROLLBACK"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "loan_core"/, 'no callback into the owner (acyclic)');
});

test('loan_core delegates resolve+GL to the posting module', () => {
  const src = srcOf('loan_core');
  assert.match(src, /CALL "loan_posting_core"/, 'loan_core must CALL the posting module');
  assert.doesNotMatch(src, /^ {7,8}CLAIM-DISBURSE-REQUEST\.$/m, 'moved paragraph must be gone');
  assert.doesNotMatch(src, /^ {7,8}DELETE-DISBURSE-REQUEST\.$/m, 'moved paragraph must be gone');
  assert.doesNotMatch(src, /^ {7,8}CLAIM-REPAY-REQUEST\.$/m, 'moved paragraph must be gone');
  assert.doesNotMatch(src, /^ {7,8}DELETE-REPAY-REQUEST\.$/m, 'moved paragraph must be gone');
  assert.doesNotMatch(src, /Resolve the payout path/, 'moved disburse resolve must be gone');
  assert.doesNotMatch(src, /Repayments only land on disbursed loans/, 'moved repay resolve must be gone');
});

test('call graph records the new posting edges', () => {
  const doc = JSON.parse(readFileSync(path.join(ROOT, 'manifest', 'cobol_calls.json'), 'utf8'));
  const keys = new Set(doc.edges.map((e) => `${e.from} -> ${e.to}`));
  assert.ok(keys.has('loan_core -> loan_posting_core'), 'registry must list the new edge');
  assert.ok(keys.has('loan_posting_core -> gl_core'), 'registry must list the new edge');
});
