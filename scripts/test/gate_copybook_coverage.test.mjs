// Gate copybook-coverage pins (DRY-00B). No database, no build.
//
// Moving code into cobol/copy must not hide it from the gates:
//   - field sizes: an oversized query literal inside a .cpy fails;
//   - transaction ownership: BEGIN/COMMIT/ROLLBACK are counted after COPY
//     expansion, so a copybook-resident close is attributed to its host;
//   - error codes: an ERROR|CODE inside a .cpy must be registered.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeRoot() {
  const d = mkdtempSync(path.join(tmpdir(), 'copycov-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'cobol', 'src'), { recursive: true });
  mkdirSync(path.join(d, 'cobol', 'copy'), { recursive: true });
  return d;
}

function runGate(gate, root) {
  try {
    const stdout = execFileSync(process.execPath, [path.join(ROOT, 'scripts', gate), root], { encoding: 'utf8' });
    return { status: 0, out: stdout };
  } catch (e) {
    return { status: e.status ?? 1, out: String(e.stdout || '') + String(e.stderr || '') };
  }
}

test('field sizes: oversized query inside a copybook fails', () => {
  const d = makeRoot();
  writeFileSync(path.join(d, 'cobol', 'src', 'ok.cob'), 'IDENTIFICATION DIVISION.\nPROGRAM-ID. ok.\n');
  writeFileSync(
    path.join(d, 'cobol', 'copy', 'big.cpy'),
    `       SHARED-Q.\n           MOVE "${'X'.repeat(1024)}" TO WS-PREP-SQL.\n           EXIT PARAGRAPH.\n`,
  );
  const r = runGate('check_cobol_field_sizes.mjs', d);
  assert.equal(r.status, 1);
  assert.match(r.out, /query literal 1024 bytes exceeds 1023/);
});

test('field sizes: copybook declarations are checked too', () => {
  const d = makeRoot();
  writeFileSync(path.join(d, 'cobol', 'src', 'ok.cob'), 'IDENTIFICATION DIVISION.\nPROGRAM-ID. ok.\n');
  writeFileSync(
    path.join(d, 'cobol', 'copy', 'wide.cpy'),
    '       01  WS-PREP-SQL             PIC X(2048) VALUE SPACES.\n',
  );
  const r = runGate('check_cobol_field_sizes.mjs', d);
  assert.equal(r.status, 1);
  assert.match(r.out, /WS-PREP-SQL PIC X\(2048\) exceeds 1024/);
});

test('transaction ownership: copybook BEGIN without close fails the host', () => {
  const d = makeRoot();
  writeFileSync(
    path.join(d, 'cobol', 'src', 'host.cob'),
    'IDENTIFICATION DIVISION.\nPROGRAM-ID. host.\n        COPY "txn.cpy".\n',
  );
  writeFileSync(path.join(d, 'cobol', 'copy', 'txn.cpy'), '       CALL "SQL_BEGIN" END-CALL.\n');
  const r = runGate('check_transaction_ownership.mjs', d);
  assert.equal(r.status, 1);
  assert.match(r.out, /not closed on both paths/);
});

test('transaction ownership: balanced copybook body passes', () => {
  const d = makeRoot();
  writeFileSync(
    path.join(d, 'cobol', 'src', 'host.cob'),
    'IDENTIFICATION DIVISION.\nPROGRAM-ID. host.\n        COPY "txn.cpy".\n',
  );
  writeFileSync(
    path.join(d, 'cobol', 'copy', 'txn.cpy'),
    '       CALL "SQL_BEGIN" END-CALL.\n       CALL "SQL_COMMIT" END-CALL.\n       CALL "SQL_ROLLBACK" END-CALL.\n',
  );
  const r = runGate('check_transaction_ownership.mjs', d);
  assert.equal(r.status, 0);
  assert.match(r.out, /OK: transaction ownership holds/);
});

function errorFixture() {
  const d = makeRoot();
  mkdirSync(path.join(d, 'contracts'), { recursive: true });
  mkdirSync(path.join(d, 'middleware', 'core-client'), { recursive: true });
  writeFileSync(path.join(d, 'contracts', 'errors.yaml'), 'codes:\n  KNOWN_CODE: { status: 400, origin: cobol }\n');
  writeFileSync(
    path.join(d, 'middleware', 'core-client', 'result.js'),
    'export const ERROR_STATUS = {\n  KNOWN_CODE: 400,\n};\n',
  );
  writeFileSync(path.join(d, 'cobol', 'src', 'ok.cob'), 'IDENTIFICATION DIVISION.\nPROGRAM-ID. ok.\n');
  return d;
}

test('error codes: unregistered code inside a copybook fails', () => {
  const d = errorFixture();
  writeFileSync(path.join(d, 'cobol', 'copy', 'oops.cpy'), '       MOVE "ERROR|BRAND_NEW_CODE" TO LS-OUTPUT-BUFFER.\n');
  // The gate scans every .cpy (orphans are check_copybooks' failure);
  // the include below mirrors how a real host would pull the paragraph in.
  writeFileSync(
    path.join(d, 'cobol', 'src', 'ok.cob'),
    'IDENTIFICATION DIVISION.\nPROGRAM-ID. ok.\n        COPY "oops.cpy".\n',
  );
  const r = runGate('check_error_codes.mjs', d);
  assert.equal(r.status, 1);
  assert.match(r.out, /unregistered COBOL code: ERROR\|BRAND_NEW_CODE/);
});
