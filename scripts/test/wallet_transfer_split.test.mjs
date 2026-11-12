// Wallet transfer split pins (maint-07). No database, no build.
//
// wallet_transfer_core.cob owns TRANSFER-LOGIC plus its 18 helpers, moved
// verbatim except for the 4 transaction statements (JOIN pattern, ADR-0010:
// the owner opens the transaction, the callee joins it, the owner closes
// it). wallet_core keeps MAIN-LOGIC, the entry guards, the reads, and the
// single transaction per transfer. Universal invariants:
//   - the transfer module opens no transaction (0 BEGIN/COMMIT/ROLLBACK);
//   - it never calls back into wallet_core (acyclic: wallet -> transfer
//     -> {fee,payment}; fee/payment never call back);
//   - wallet_core no longer holds the moved paragraphs;
//   - the call graph records the new edges.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const srcOf = (module) => readFileSync(path.join(SRC, `${module}.cob`), 'utf8');

const MOVED = [
  'TRANSFER-LOGIC',
  'VALIDATE-AMOUNT',
  'PARSE-MAJOR',
  'CHECK-CAP-DIGITS',
  'CHECK-CAP-CHARS',
  'CHECK-RATE-STALE',
  'COMPUTE-FX-RESIDUAL',
  'CHECK-FX-ZERO',
  'CHECK-PAYMENT-POLICY',
  'RECORD-VELOCITY-USAGE',
  'CHECK-DAILY-TOTAL',
  'RECORD-DAILY-TOTAL',
  'VERIFY-JOURNAL-BALANCED',
  'LOOKUP-TRANSFER-FEE',
  'POST-FEE-JOURNAL',
  'POST-FX-RESIDUAL',
  'VERIFY-JOURNAL-FX-BALANCED',
  'CHECK-TRANSIENT',
  'LOCK-ACCOUNTS',
];

test('wallet_transfer_core defines TRANSFER-LOGIC and its helpers', () => {
  const src = srcOf('wallet_transfer_core');
  for (const name of MOVED) {
    assert.match(src, new RegExp(`^ {8}${name}\\.$`, 'm'), `transfer module must define ${name}`);
  }
});

test('wallet_transfer_core opens no transaction and never calls back', () => {
  const src = srcOf('wallet_transfer_core');
  assert.doesNotMatch(src, /CALL "SQL_BEGIN"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "SQL_COMMIT"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "SQL_ROLLBACK"/, 'caller owns the single transaction');
  assert.doesNotMatch(src, /CALL "wallet_core"/, 'no callback into the owner (acyclic)');
  assert.doesNotMatch(src, /CALL "gl_core"/, 'no new GL seam (unchanged behavior)');
});

test('wallet_core delegates the transfer to the transfer module', () => {
  const src = srcOf('wallet_core');
  assert.match(src, /CALL "wallet_transfer_core"/, 'wallet_core must CALL the transfer module');
  assert.doesNotMatch(src, /^ {8}POST-FEE-JOURNAL\.$/m, 'moved paragraph must be gone');
  assert.doesNotMatch(src, /^ {8}LOCK-ACCOUNTS\.$/m, 'moved paragraph must be gone');
  assert.doesNotMatch(src, /SELF_TRANSFER/, 'moved transfer body must be gone');
  assert.doesNotMatch(src, /AMBIGUOUS_ACCOUNT/, 'moved transfer body must be gone');
});

test('call graph records the new transfer edges', () => {
  const doc = JSON.parse(readFileSync(path.join(ROOT, 'manifest', 'cobol_calls.json'), 'utf8'));
  const keys = new Set(doc.edges.map((e) => `${e.from} -> ${e.to}`));
  assert.ok(keys.has('wallet_core -> wallet_transfer_core'), 'registry must list the new edge');
  assert.ok(keys.has('wallet_transfer_core -> fee_core'), 'registry must list the join edge');
  assert.ok(keys.has('wallet_transfer_core -> payment_core'), 'registry must list the join edge');
});
