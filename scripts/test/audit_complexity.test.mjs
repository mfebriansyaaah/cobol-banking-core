// Unit tests for scripts/audit_complexity.mjs. No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'audit_complexity.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

// Minimal repo tree exercising every collector: 1 clone-shaped COBOL module,
// 1 non-clone module, 1 route file + app.js, 1 migration, 1 suite + 1 case.
function makeRoot() {
  const d = mkdtempSync(path.join(tmpdir(), 'auditcx-'));
  dirs.push(d);
  const cobolDir = path.join(d, 'cobol', 'src');
  mkdirSync(cobolDir, { recursive: true });
  const actions = ['CREATE', 'LIST', 'GET', 'CALC', 'UPDATE', 'DELETE', 'SUMMARY', 'AUDIT', 'VALIDATE']
    .map((s) => {
      const name = `TST_${s}`;
      return `               WHEN LS-CMD-ACTION(1:${name.length}) = "${name}"`;
    })
    .join('\n');
  const clone = ['IDENTIFICATION DIVISION.', 'PROGRAM-ID. tst_core.', actions, ''].join('\n');
  // Pad to exactly 669 lines to exercise the exact-669 counter.
  const pad = Array.from({ length: 669 - clone.split('\n').length + 1 }, (_, i) => `      *> pad ${i}.`).join('\n');
  writeFileSync(path.join(cobolDir, 'tst_core.cob'), `${clone}${pad}`);
  writeFileSync(path.join(cobolDir, 'main_logic.cob'), 'IDENTIFICATION DIVISION.\nPROGRAM-ID. main_logic.\n');
  writeFileSync(path.join(cobolDir, 'other_core.cob'), 'IDENTIFICATION DIVISION.\nPROGRAM-ID. other.\n');

  const routes = path.join(d, 'middleware', 'src', 'routes');
  mkdirSync(routes, { recursive: true });
  writeFileSync(
    path.join(routes, 'demo.js'),
    [
      'export const DEMO_ROUTES = [',
      "  { method: 'get', path: '/demo', action: 'COVERED', fields: [] },",
      "  { method: 'post', path: '/demo', action: 'MISSING', fields: [] },",
      '];',
      '',
    ].join('\n'),
  );
  writeFileSync(path.join(routes, 'index.js'), 'export const ALL_ROUTES = [];\n');
  writeFileSync(
    path.join(d, 'middleware', 'src', 'app.js'),
    ['export const ROUTES = [', "  { method: 'get', path: '/app', action: 'APP_ONLY', fields: [] },", '];', ''].join(
      '\n',
    ),
  );

  const migDir = path.join(d, 'database', 'migrations');
  mkdirSync(migDir, { recursive: true });
  writeFileSync(
    path.join(migDir, '0001_demo.sql'),
    'CREATE TABLE IF NOT EXISTS demo (id INT PRIMARY KEY) ENGINE=InnoDB;\nCREATE TABLE demo_audit (id INT) ENGINE=InnoDB;\n',
  );
  writeFileSync(path.join(d, 'database', 'schema.sql'), 'CREATE TABLE IF NOT EXISTS demo (id INT) ENGINE=InnoDB;\n');
  writeFileSync(path.join(d, 'database', 'schema_full.sql'), '-- full\n');

  const db = path.join(d, 'tests', 'db');
  mkdirSync(db, { recursive: true });
  writeFileSync(path.join(db, 'demo_db_tests.sh'), '#!/usr/bin/env bash\nrun_cobol "COVERED|x|||||a@b.c"\n');
  const cases = path.join(d, 'tests', 'cobol', 'cases');
  mkdirSync(cases, { recursive: true });
  writeFileSync(path.join(cases, 'demo.cases'), 'name@@SUCCESS\\\\|ok@@APP_ONLY|x|||||a@b.c\n');
  writeFileSync(path.join(d, 'tests', 'action_test_coverage_baseline.txt'), 'MISSING\n');
  mkdirSync(path.join(d, 'tests', 'contracts'), { recursive: true });
  writeFileSync(path.join(d, 'tests', 'contracts', 'route_field_order.json'), '{}');
  return d;
}

function run(root, extra = []) {
  return execFileSync(process.execPath, [GATE, '--root', root, ...extra], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

test('--json reports fixture numbers', () => {
  const d = makeRoot();
  const stats = JSON.parse(run(d, ['--json']));
  assert.equal(stats.cobol.files, 3);
  assert.equal(stats.cobol.modules, 2);
  assert.equal(stats.cobol.exact669, 1);
  assert.equal(stats.cobol.canonical9, 1);
  assert.equal(stats.gateway.routeFiles, 1);
  assert.equal(stats.gateway.routeDefinitions, 3);
  assert.equal(stats.gateway.mutatingRoutes, 1);
  assert.equal(stats.database.migrations, 1);
  assert.equal(stats.database.uniqueTables, 2);
  assert.equal(stats.database.auditTables, 1);
  assert.equal(stats.actions.routeActions, 3);
  assert.equal(stats.actions.shellCovered, 2);
  assert.equal(stats.actions.untested, 1);
  assert.equal(stats.actions.baselineEntries, 1);
});

test('--markdown renders the baseline table', () => {
  const d = makeRoot();
  const out = run(d, ['--markdown']);
  assert.match(out, /# Complexity Baseline/);
  assert.match(out, /canonical 9-action clones/);
  assert.match(out, /mutating routes/);
});

test('--write creates docs/COMPLEXITY_BASELINE.md', () => {
  const d = makeRoot();
  mkdirSync(path.join(d, 'docs'), { recursive: true });
  run(d, ['--write']);
  assert.ok(existsSync(path.join(d, 'docs', 'COMPLEXITY_BASELINE.md')));
  assert.match(readFileSync(path.join(d, 'docs', 'COMPLEXITY_BASELINE.md'), 'utf8'), /# Complexity Baseline/);
});

test('unknown flag exits 2', () => {
  const d = makeRoot();
  try {
    run(d, ['--bogus']);
  } catch (e) {
    assert.match(String(e.status), /2/);
    return;
  }
  assert.fail('expected failure for --bogus');
});
