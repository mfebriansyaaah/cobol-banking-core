// Card posting split pins (maint-05). No database, no build.
//
// card_posting_core.cob owns the resolve+GL-post paragraphs for capture,
// repay, and reverse (CARD_POST_CAPTURE/REPAY/REVERSE). card_core keeps the
// action dispatch, the idempotency claims, and the single transaction per
// action. Universal invariants:
//   - the posting module opens no transaction (0 BEGIN/COMMIT/ROLLBACK);
//   - it never calls back into card_core (acyclic: card -> posting -> gl);
//   - card_core no longer holds the moved resolve blocks or the moved
//     PREPARE-REFUND-POSTING paragraph;
//   - the call graph records both new edges.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const srcOf = (module) => readFileSync(path.join(SRC, `${module}.cob`), 'utf8');

test('card_posting_core defines the three posting actions', () => {
  const src = srcOf('card_posting_core');
  for (const name of ['ACTION-POST-CAPTURE', 'ACTION-POST-REPAY', 'ACTION-POST-REVERSE']) {
    assert.match(src, new RegExp(`^ {7}${name}\\.$`, 'm'), `posting module must define ${name}`);
  }
});

test('card_posting_core opens no transaction and never calls back', () => {
  const src = srcOf('card_posting_core');
  assert.doesNotMatch(src, /CALL "SQL_BEGIN"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "SQL_COMMIT"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "SQL_ROLLBACK"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "card_core"/, 'no callback into the owner (acyclic)');
});

test('card_core delegates resolve+GL to the posting module', () => {
  const src = srcOf('card_core');
  assert.match(src, /CALL "card_posting_core"/, 'card_core must CALL the posting module');
  assert.doesNotMatch(src, /^ {7}PREPARE-REFUND-POSTING\.$/m, 'moved paragraph must be gone');
  assert.doesNotMatch(src, /Resolve the capture path/, 'moved capture resolve block must be gone');
  assert.doesNotMatch(src, /Resolve the repayment path/, 'moved repay resolve block must be gone');
});

test('call graph records the new posting edges', () => {
  const doc = JSON.parse(readFileSync(path.join(ROOT, 'manifest', 'cobol_calls.json'), 'utf8'));
  const keys = new Set(doc.edges.map((e) => `${e.from} -> ${e.to}`));
  assert.ok(keys.has('card_core -> card_posting_core'), 'registry must list card_core -> card_posting_core');
  assert.ok(keys.has('card_posting_core -> gl_core'), 'registry must list card_posting_core -> gl_core');
});
