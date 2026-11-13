// Unified idempotency store pins (maint-14A/14B). No database, no build.
//
// PR-14 replaces the ten per-action `*_request` tables with one generic
// `idempotency_request(scope, entity_ref, key, ...)` mirror, accessed
// through cobol/copy/common_idem.cpy (IDEM-CLAIM / IDEM-COMPLETE /
// IDEM-DELETE). The legacy tables stay the decision-makers in this
// release (ADR-0008): the copybook writes both stores, reads decide from
// the legacy row, and the suites prove the mirror converges. 14A lands
// the table + the copybook + the collection pilot (COL_PAY); 14B migrates
// the other four domains (card, deposit, loan, payment clearing).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

test('unified idempotency migration exists with the documented shape', () => {
  const dir = path.join(ROOT, 'database', 'migrations');
  const found = readdirSync(dir)
    .filter((f) => f.endsWith('.sql'))
    .map((f) => path.join(dir, f))
    .filter(
      (p) =>
        readFileSync(p, 'utf8').includes('CREATE TABLE') && readFileSync(p, 'utf8').includes('idempotency_request'),
    );
  assert.equal(found.length, 1, 'exactly one migration must create idempotency_request');
  const sql = readFileSync(found[0], 'utf8');
  for (const col of [
    'scope',
    'entity_ref',
    'idem_key',
    'amount',
    'details',
    'status',
    'gl_journal_id',
    'created_at',
    'updated_at',
  ]) {
    assert.match(sql, new RegExp(`\\b${col}\\b`), `migration must define column ${col}`);
  }
  assert.match(sql, /UNIQUE/i, 'migration must constrain (scope, entity_ref, key) to one row');
  assert.match(sql, /'PENDING'\s*,\s*'DONE'/, 'migration must keep the PENDING/DONE protocol');
});

test('schema snapshot contains the unified table', () => {
  const snap = readFileSync(path.join(ROOT, 'database', 'schema_full.sql'), 'utf8');
  assert.match(snap, /CREATE TABLE `idempotency_request`/, 'schema_full.sql must be regenerated with the new table');
});

test('common_idem.cpy provides the three dual-store paragraphs', () => {
  const p = path.join(ROOT, 'cobol', 'copy', 'common_idem.cpy');
  assert.ok(existsSync(p), 'cobol/copy/common_idem.cpy must exist');
  const src = readFileSync(p, 'utf8');
  for (const para of ['IDEM-CLAIM', 'IDEM-COMPLETE', 'IDEM-DELETE']) {
    assert.match(src, new RegExp(`^ {7}${para}\\.$`, 'm'), `copybook must define ${para}`);
  }
  for (const field of [
    'WS-IDEM-SCOPE',
    'WS-IDEM-TABLE',
    'WS-IDEM-ENTITY',
    'WS-IDEM-ENTITY-VAL',
    'WS-IDEM-KEY',
    'WS-IDEM-AMOUNT',
    'WS-IDEM-CODE',
  ]) {
    assert.match(src, new RegExp(`\\b${field}\\b`), `copybook must document interface field ${field}`);
  }
  assert.match(src, /idempotency_request/, 'copybook must mirror into the unified table');
});

test('collection pilot routes every pay_request access through the copybook', () => {
  const src = readFileSync(path.join(ROOT, 'cobol', 'src', 'collection_core.cob'), 'utf8');
  assert.match(src, /COPY "common_idem\.cpy"/, 'collection_core must COPY the shared copybook');
  assert.equal(
    (src.match(/collection_pay_request/g) || []).length,
    0,
    'no legacy-table SQL may remain in collection_core (it lives in the copybook)',
  );
  for (const para of ['IDEM-CLAIM', 'IDEM-COMPLETE', 'IDEM-DELETE']) {
    assert.match(src, new RegExp(`PERFORM ${para}\\b`), `collection_core must PERFORM ${para}`);
  }
});

test('14B domains route every *_request access through the copybook', () => {
  const cases = [
    ['card_core.cob', ['card_capture_request', 'card_repay_request', 'card_reverse_request']],
    ['deposit_core.cob', ['deposit_open_request', 'deposit_close_request', 'deposit_settle_request']],
    ['deposit_posting_core.cob', ['deposit_settle_request']],
    ['loan_posting_core.cob', ['loan_disburse_request', 'loan_repay_request']],
    ['loan_core.cob', ['loan_disburse_request', 'loan_repay_request']],
    ['payment_clearing_core.cob', ['payment_settle_request']],
  ];
  for (const [file, tables] of cases) {
    const src = readFileSync(path.join(ROOT, 'cobol', 'src', file), 'utf8');
    assert.match(src, /COPY "common_idem\.cpy"/, `${file} must COPY the shared copybook`);
    for (const t of tables) {
      assert.equal(
        (src.match(new RegExp(t, 'g')) || []).length,
        0,
        `no ${t} SQL may remain in ${file} (it lives in the copybook)`,
      );
    }
    for (const para of ['IDEM-CLAIM', 'IDEM-COMPLETE', 'IDEM-DELETE']) {
      assert.match(src, new RegExp(`PERFORM ${para}\\b`), `${file} must PERFORM ${para}`);
    }
  }
});

test('copybook covers the 14B scopes and journal variants', () => {
  const src = readFileSync(path.join(ROOT, 'cobol', 'copy', 'common_idem.cpy'), 'utf8');
  for (const scope of [
    'CARD_CAPTURE',
    'CARD_REPAY',
    'CARD_REVERSE',
    'DEP_OPEN',
    'DEP_CLOSE',
    'DEP_SETTLE',
    'LOAN_DISBURSE',
    'LOAN_REPAY',
    'PMC_SETTLE',
  ]) {
    assert.match(src, new RegExp(`"${scope}"`), `copybook must map scope ${scope}`);
  }
  for (const field of ['WS-IDEM-SETCOL', 'WS-IDEM-JIDVAL', 'WS-IDEM-DETAIL-COLS', 'WS-IDEM-IDCOL']) {
    assert.match(src, new RegExp(`\\b${field}\\b`), `copybook must document interface field ${field}`);
  }
});
