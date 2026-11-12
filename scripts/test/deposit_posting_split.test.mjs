// Deposit posting split pins (maint-06). No database, no build.
//
// deposit_posting_core.cob owns the pre-transaction resolve+GL-post for
// accrue, post-interest, and settle (DEP_POST_ACCRUE/INTEREST/SETTLE),
// including the settle idempotency helpers. deposit_core keeps the action
// dispatch, the auth guards, and the single transaction per action.
// Universal invariants:
//   - the posting module opens no transaction (0 BEGIN/COMMIT/ROLLBACK);
//   - it never calls back into deposit_core (acyclic: deposit -> posting -> gl);
//   - deposit_core no longer holds the moved resolve blocks or the moved
//     CLAIM/DELETE-SETTLE-REQUEST paragraphs;
//   - the call graph records both new edges.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const srcOf = (module) => readFileSync(path.join(SRC, `${module}.cob`), 'utf8');

test('deposit_posting_core defines the three posting actions', () => {
  const src = srcOf('deposit_posting_core');
  for (const name of ['ACTION-POST-ACCRUE', 'ACTION-POST-INTEREST', 'ACTION-POST-SETTLE']) {
    assert.match(src, new RegExp(`^ {7}${name}\\.$`, 'm'), `posting module must define ${name}`);
  }
  for (const name of ['CLAIM-SETTLE-REQUEST', 'DELETE-SETTLE-REQUEST']) {
    assert.match(src, new RegExp(`^ {7}${name}\\.$`, 'm'), `posting module must own ${name}`);
  }
});

test('deposit_posting_core opens no transaction and never calls back', () => {
  const src = srcOf('deposit_posting_core');
  assert.doesNotMatch(src, /CALL "SQL_BEGIN"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "SQL_COMMIT"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "SQL_ROLLBACK"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "deposit_core"/, 'no callback into the owner (acyclic)');
});

test('deposit_core delegates resolve+GL to the posting module', () => {
  const src = srcOf('deposit_core');
  assert.match(src, /CALL "deposit_posting_core"/, 'deposit_core must CALL the posting module');
  assert.doesNotMatch(src, /^ {7}CLAIM-SETTLE-REQUEST\.$/m, 'moved paragraph must be gone');
  assert.doesNotMatch(src, /^ {7}DELETE-SETTLE-REQUEST\.$/m, 'moved paragraph must be gone');
  assert.doesNotMatch(src, /Resolve the payout path/, 'moved settle resolve must be gone');
  assert.doesNotMatch(src, /NOTHING_TO_POST/, 'moved interest resolve must be gone');
  assert.doesNotMatch(
    src,
    /SELECT status FROM deposit_account WHERE id = \? LIMIT 1/,
    'moved accrue resolve must be gone',
  );
});

test('call graph records the new posting edges', () => {
  const doc = JSON.parse(readFileSync(path.join(ROOT, 'manifest', 'cobol_calls.json'), 'utf8'));
  const keys = new Set(doc.edges.map((e) => `${e.from} -> ${e.to}`));
  assert.ok(keys.has('deposit_core -> deposit_posting_core'), 'registry must list the new edge');
  assert.ok(keys.has('deposit_posting_core -> gl_core'), 'registry must list the new edge');
});
