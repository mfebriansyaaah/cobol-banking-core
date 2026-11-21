// Unit tests for scripts/check_architecture.mjs (arch9 WP-01).
// Each test builds a minimal fixture tree in a temp dir and runs the
// checker against it. Fixtures must stay tiny: they prove the rule fires,
// not the whole repo.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const CHECKER = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'check_architecture.mjs');

function fixture(files) {
  const root = mkdtempSync(path.join(tmpdir(), 'arch-'));
  for (const [name, content] of Object.entries(files)) {
    const p = path.join(root, name);
    mkdirSync(path.dirname(p), { recursive: true });
    writeFileSync(p, content);
  }
  return root;
}

function run(root) {
  try {
    const out = execFileSync('node', [CHECKER, root], { encoding: 'utf8' });
    return { code: 0, out };
  } catch (err) {
    return { code: err.status, out: String(err.stdout || '') + String(err.stderr || '') };
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

const COB_HEAD = '       IDENTIFICATION DIVISION.\n       PROGRAM-ID. X.\n';

test('A1 fires on direct SQL_BEGIN, passes on TXN-BEGIN', () => {
  const bad = run(fixture({ 'cobol/src/a_core.cob': `${COB_HEAD}           CALL "SQL_BEGIN" END-CALL\n` }));
  assert.equal(bad.code, 1);
  assert.match(bad.out, /A1/);
  const good = run(fixture({ 'cobol/src/a_core.cob': `${COB_HEAD}           PERFORM TXN-BEGIN\n` }));
  assert.equal(good.code, 0);
});

test('A1 ignores the TXN-BEGIN kernel copybook', () => {
  const r = run(fixture({ 'cobol/copy/common_txn.cpy': '       CALL "SQL_BEGIN" END-CALL\n' }));
  assert.equal(r.code, 0);
});

test('A1 allowlist covers listed files and rejects stale lines', () => {
  const r = run(
    fixture({
      'cobol/src/a_core.cob': `${COB_HEAD}           CALL "SQL_BEGIN" END-CALL\n`,
      'tests/architecture_sql_begin_allowlist.txt':
        'cobol/src/a_core.cob|arch9|2099-01-01|test\ncobol/src/gone.cob|arch9|2099-01-01|test\n',
    }),
  );
  assert.equal(r.code, 1);
  assert.match(r.out, /stale/);
});

test('A2 fires on bare SQL_COMMIT in src', () => {
  const r = run(fixture({ 'cobol/src/a_core.cob': `${COB_HEAD}           CALL "SQL_COMMIT" END-CALL\n` }));
  assert.equal(r.code, 1);
  assert.match(r.out, /A2/);
});

test('A3 fires on DENIED audit status', () => {
  const r = run(fixture({ 'cobol/src/a_core.cob': `${COB_HEAD}           MOVE 'DENIED' TO WS-X\n` }));
  assert.equal(r.code, 1);
  assert.match(r.out, /A3/);
});

test('A4 fires on gl_journal description lookup', () => {
  const r = run(
    fixture({
      'cobol/src/a_core.cob': `${COB_HEAD}           MOVE "SELECT id FROM gl_journal WHERE description = ?" TO WS-PREP-SQL\n`,
    }),
  );
  assert.equal(r.code, 1);
  assert.match(r.out, /A4/);
});

test('A5 fires on direct services import in middleware/src', () => {
  const bad = run(fixture({ 'middleware/src/a.js': "import { x } from '../services/y.js';\n" }));
  assert.equal(bad.code, 1);
  assert.match(bad.out, /A5/);
  const good = run(fixture({ 'middleware/adapters/a.js': "import { x } from '../services/y.js';\n" }));
  assert.equal(good.code, 0);
});

test('A5 exception allowlists server.js until WP-21', () => {
  const r = run(
    fixture({
      'middleware/src/server.js': "import { x } from '../services/y.js';\n",
      'tests/architecture_exceptions.txt': 'A5:middleware/src/server.js|arch9|2099-01-01|test\n',
    }),
  );
  assert.equal(r.code, 0);
});

test('A6 fires above 1000 lines and respects the allowlist', () => {
  const big = `${COB_HEAD}${'           MOVE 1 TO X.\n'.repeat(1005)}`;
  const bad = run(fixture({ 'cobol/src/big_core.cob': big }));
  assert.equal(bad.code, 1);
  assert.match(bad.out, /A6/);
  const good = run(
    fixture({
      'cobol/src/big_core.cob': big,
      'tests/architecture_module_size_allowlist.txt': 'cobol/src/big_core.cob|arch9|2099-01-01|test\n',
    }),
  );
  assert.equal(good.code, 0);
});

test('A7 fires on duplicate actions and respects legacy_routes.txt', () => {
  const route = (action) =>
    `export const R = [{ method: 'get', path: '/a', action: '${action}', fields: [] }, { method: 'get', path: '/b', action: '${action}', fields: [] }];\n`;
  const bad = run(fixture({ 'middleware/src/routes/dup.js': route('DUP_ACT') }));
  assert.equal(bad.code, 1);
  assert.match(bad.out, /A7/);
  const good = run(
    fixture({
      'middleware/src/routes/dup.js': route('DUP_ACT'),
      'tests/legacy_routes.txt': 'DUP_ACT|2099-01-01|arch9|test\n',
    }),
  );
  assert.equal(good.code, 0);
});

test('A7 ignores routes marked deprecated:true', () => {
  const route = `export const R = [{ method: 'get', path: '/a', action: 'DUP_ACT', deprecated: true, fields: [] }, { method: 'get', path: '/b', action: 'DUP_ACT', deprecated: true, fields: [] }];\n`;
  const r = run(fixture({ 'middleware/src/routes/dup.js': route }));
  assert.equal(r.code, 0);
});

test('expired exceptions fail', () => {
  const r = run(
    fixture({
      'cobol/src/a_core.cob': `${COB_HEAD}           CALL "SQL_BEGIN" END-CALL\n`,
      'tests/architecture_sql_begin_allowlist.txt': 'cobol/src/a_core.cob|arch9|2000-01-01|test\n',
    }),
  );
  assert.equal(r.code, 1);
  assert.match(r.out, /expired/);
});

test('malformed allowlist entries fail', () => {
  const r = run(fixture({ 'tests/architecture_sql_begin_allowlist.txt': 'no-pipes-here\n' }));
  assert.equal(r.code, 1);
  assert.match(r.out, /malformed/);
});

test('clean tree passes', () => {
  const r = run(
    fixture({
      'cobol/src/a_core.cob': `${COB_HEAD}           PERFORM TXN-BEGIN\n`,
      'middleware/src/a.js': "import { x } from '../adapters/y.js';\n",
    }),
  );
  assert.equal(r.code, 0);
  assert.match(r.out, /OK: architecture rules pass/);
});

const UPDATE_CORE = (tail) =>
  `${COB_HEAD}       DO-IT.\n           MOVE "UPDATE loan SET status = 'X' WHERE id = ? AND status = 'Y'" TO WS-PREP-SQL\n           PERFORM SQL-EXEC-1\n${tail}\n           EXIT PARAGRAPH.\n`;

test('A8 fires on a guarded status UPDATE without outcome handling', () => {
  const r = run(fixture({ 'cobol/src/a_core.cob': UPDATE_CORE('           MOVE 1 TO WS-X.\n') }));
  assert.equal(r.code, 1);
  assert.match(r.out, /A8/);
});

test('A8 passes with STATE-EXPECT-ONE', () => {
  const r = run(
    fixture({ 'cobol/src/a_core.cob': UPDATE_CORE('           PERFORM STATE-EXPECT-ONE\n           IF WS-STATE-OK = 0\n               EXIT PARAGRAPH\n           END-IF.\n') }),
  );
  assert.equal(r.code, 0);
});

test('A8 passes with an explicit AFFECTED check', () => {
  const r = run(
    fixture({
      'cobol/src/a_core.cob': UPDATE_CORE('           IF WS-RESULT = "SUCCESS|AFFECTED_0"\n               MOVE 1 TO WS-X.\n           END-IF.\n'),
    }),
  );
  assert.equal(r.code, 0);
});

test('A8 allowlist covers legacy paragraphs and rejects stale lines', () => {
  const bad = UPDATE_CORE('           MOVE 1 TO WS-X.\n');
  const r = run(
    fixture({
      'cobol/src/a_core.cob': bad,
      'tests/state_transition_allowlist.txt': 'cobol/src/a_core.cob::DO-IT|arch9|2099-01-01|test\n',
    }),
  );
  assert.equal(r.code, 0);
  const stale = run(
    fixture({
      'cobol/src/a_core.cob': UPDATE_CORE('           PERFORM STATE-EXPECT-ONE\n'),
      'tests/state_transition_allowlist.txt': 'cobol/src/a_core.cob::DO-IT|arch9|2099-01-01|test\n',
    }),
  );
  assert.equal(stale.code, 1);
  assert.match(stale.out, /stale/);
});
