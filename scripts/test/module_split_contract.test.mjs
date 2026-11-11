// Module-split contract pins (maint-00a, ADR-0010). No database, no build.
//
// The PR-05–09 module splits move paragraphs into new modules that are
// CALLed from inside the owner's open transaction. That is only safe when
// the callee issues NO transaction statements of its own: SQL_BEGIN on an
// open transaction rolls the caller's work back (see sql_bridge.c), and a
// callee COMMIT would commit the caller's partial work early.
//
// This test pins the production precedent that already proves the pattern:
// wallet_core CALLs fee_core (VEL_RECORD_ALL_TXN) and payment_core
// (PAY_ENFORCE) from inside its transfer transaction, and both callee
// paragraphs contain zero SQL_BEGIN/COMMIT/ROLLBACK. If a future edit adds
// a transaction statement to either paragraph, this test fails before the
// money moves.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const COBOL_DIR = path.join(ROOT, 'cobol', 'src');

const TXN_RE = /CALL\s+"SQL_(BEGIN|COMMIT|ROLLBACK)"/g;

// Extract one paragraph body: from the header line to the next paragraph
// header or end of file. Paragraph headers start in area A (column 8+).
function paragraph(src, name) {
  const lines = src.split('\n');
  const start = lines.findIndex((l) => new RegExp(`^ {7}${name}\\.$`).test(l));
  assert.ok(start !== -1, `paragraph ${name} not found`);
  let end = lines.length;
  for (let i = start + 1; i < lines.length; i += 1) {
    if (/^ {7}[A-Z][A-Z0-9-]*\.$/.test(lines[i])) {
      end = i;
      break;
    }
  }
  return lines.slice(start, end).join('\n');
}

const txnCount = (body) => (body.match(TXN_RE) || []).length;

test('fee_core VEL_RECORD_ALL_TXN joins the caller transaction (no txn statements)', () => {
  const src = readFileSync(path.join(COBOL_DIR, 'fee_core.cob'), 'utf8');
  const body = paragraph(src, 'ACTION-VEL-RECORD-ALL-TXN');
  assert.equal(txnCount(body), 0, 'callee must not BEGIN/COMMIT/ROLLBACK');
});

test('payment_core ACTION-ENFORCE joins the caller transaction (no txn statements)', () => {
  const src = readFileSync(path.join(COBOL_DIR, 'payment_core.cob'), 'utf8');
  const body = paragraph(src, 'ACTION-ENFORCE');
  assert.equal(txnCount(body), 0, 'callee must not BEGIN/COMMIT/ROLLBACK');
});

test('wallet_core calls both callees (the proven join sites)', () => {
  const src = readFileSync(path.join(COBOL_DIR, 'wallet_core.cob'), 'utf8');
  assert.match(src, /CALL\s+"fee_core"/, 'wallet_core must CALL fee_core');
  assert.match(src, /CALL\s+"payment_core"/, 'wallet_core must CALL payment_core');
});

test('call-graph registry lists the proven join edges', async () => {
  const doc = JSON.parse(readFileSync(path.join(ROOT, 'manifest', 'cobol_calls.json'), 'utf8'));
  const keys = new Set(doc.edges.map((e) => `${e.from} -> ${e.to}`));
  for (const e of ['wallet_core -> fee_core', 'wallet_core -> payment_core']) {
    assert.ok(keys.has(e), `registry must list ${e}`);
  }
});

test('bridge documents the nested-BEGIN rule (leaked txn is rolled back)', () => {
  const src = readFileSync(path.join(COBOL_DIR, 'sql_bridge.c'), 'utf8');
  assert.match(src, /Rolled back a leaked transaction/, 'SQL_BEGIN must roll back a leaked open transaction');
  assert.match(src, /START TRANSACTION/, 'SQL_BEGIN must start exactly one transaction');
});
