// Unit tests for scripts/build_tier1_graph.mjs and check_tier1_links.mjs.
// No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const BUILD = path.join(ROOT, 'scripts', 'build_tier1_graph.mjs');
const CHECK = path.join(ROOT, 'scripts', 'check_tier1_links.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

// Fixture tree: one T1 module, one L3 (two money tables + suite), one L2
// (single table + suite), one L0 (own table only), one L1 (users only),
// one UTILITY, one dispatch table, one route file, one DB suite.
function makeRoot() {
  const d = mkdtempSync(path.join(tmpdir(), 'tier1-'));
  dirs.push(d);
  const manifest = path.join(d, 'manifest');
  mkdirSync(manifest, { recursive: true });
  writeFileSync(
    path.join(manifest, 'tier1.json'),
    JSON.stringify({
      tier1Modules: ['core_core'],
      utilityModules: ['util_core'],
      businessTables: ['ledger', 'accounts'],
      moneyTables: ['ledger', 'accounts'],
      moneyActions: ['TRANSFER'],
      referenceTables: ['users', 'currencies'],
    }),
  );
  const cobolDir = path.join(d, 'cobol', 'src');
  mkdirSync(cobolDir, { recursive: true });
  const mod = (name, body) => writeFileSync(path.join(cobolDir, `${name}.cob`), `${body}\n`);
  mod('core_core', 'IDENTIFICATION DIVISION.\nPROGRAM-ID. core_core.\n');
  mod('linked_core', 'SELECT a FROM ledger WHERE id = ?\nSELECT b FROM accounts WHERE id = ?\nrun x\n');
  mod('single_core', 'INSERT INTO ledger (id) VALUES (?)\n');
  mod('orphan_core', 'INSERT INTO orphan_audit (id) VALUES (?)\n');
  mod('useronly_core', 'SELECT role FROM users WHERE email = ? LIMIT 1\n');
  mod('util_core', 'IDENTIFICATION DIVISION.\nPROGRAM-ID. util_core.\n');
  writeFileSync(
    path.join(cobolDir, 'main_logic.cob'),
    [
      'IDENTIFICATION DIVISION.',
      '       PROGRAM-ID. main_logic.',
      '       01 CMD-ACTION PIC X(20).',
      '       01 DISPATCH-TABLE.',
      '           05 DISPATCH-ENTRY OCCURS 10 TIMES.',
      '               10 D-PREFIX PIC X(20).',
      '               10 D-PREFIX-LEN PIC 9(2).',
      '               10 D-PROGRAM PIC X(32).',
      '       PROCEDURE DIVISION.',
      '       INIT-DISPATCH-TABLE.',
      '           MOVE "LNK_" TO D-PREFIX(1).',
      '           MOVE 4 TO D-PREFIX-LEN(1).',
      '           MOVE "linked_core" TO D-PROGRAM(1).',
      '',
    ].join('\n'),
  );
  const db = path.join(d, 'tests', 'db');
  mkdirSync(db, { recursive: true });
  writeFileSync(path.join(db, 'linked_db_tests.sh'), '#!/usr/bin/env bash\nrun_cobol "LNK_CREATE|x|||||a@b.c"\n');
  writeFileSync(path.join(db, 'single_db_tests.sh'), '#!/usr/bin/env bash\nrun_cobol "SNG_CREATE|x|||||a@b.c"\n');
  const routes = path.join(d, 'middleware', 'src', 'routes');
  mkdirSync(routes, { recursive: true });
  writeFileSync(
    path.join(routes, 'linked.js'),
    "export const LNK_ROUTES = [\n  { method: 'post', path: '/linked', action: 'LNK_CREATE', fields: [] },\n];\n",
  );
  writeFileSync(path.join(routes, 'index.js'), 'export const ALL_ROUTES = [];\n');
  const appDir = path.join(d, 'middleware', 'src');
  writeFileSync(path.join(appDir, 'app.js'), 'export const ROUTES = [];\n');
  mkdirSync(path.join(d, 'docs'), { recursive: true });
  mkdirSync(path.join(d, 'tests'), { recursive: true });
  return d;
}

function run(gate, root, extra = []) {
  return execFileSync(process.execPath, [gate, '--root', root, ...extra], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function runFail(gate, root, extra = []) {
  try {
    run(gate, root, extra);
  } catch (e) {
    return String((e && e.stderr) || e);
  }
  assert.fail(`expected failure for ${extra.join(' ')}`);
  return '';
}

function level(d, module) {
  const links = JSON.parse(readFileSync(path.join(d, 'manifest', 'tier1_links.json'), 'utf8'));
  return links.modules.find((m) => m.module === module).linkageLevel;
}

test('scoring assigns L3/L2/L1/L0/UTILITY', () => {
  const d = makeRoot();
  run(BUILD, d, ['--write']);
  assert.equal(level(d, 'core_core'), 'L3');
  assert.equal(level(d, 'linked_core'), 'L3');
  assert.equal(level(d, 'single_core'), 'L2');
  assert.equal(level(d, 'orphan_core'), 'L0');
  assert.equal(level(d, 'useronly_core'), 'L1');
  assert.equal(level(d, 'util_core'), 'UTILITY');
});

test('admin-guard-only module is L1, not linked', () => {
  const d = makeRoot();
  run(BUILD, d, ['--write']);
  const links = JSON.parse(readFileSync(path.join(d, 'manifest', 'tier1_links.json'), 'utf8'));
  const m = links.modules.find((x) => x.module === 'useronly_core');
  assert.equal(m.linkageLevel, 'L1');
  assert.deepEqual(m.businessTables, []);
});

test('check passes when baseline matches', () => {
  const d = makeRoot();
  run(BUILD, d, ['--write']);
  run(BUILD, d, ['--write-baseline']);
  const out = run(CHECK, d);
  assert.match(out, /OK: linkage in sync/);
});

test('check fails on new unlisted L0 module', () => {
  const d = makeRoot();
  run(BUILD, d, ['--write']);
  run(BUILD, d, ['--write-baseline']);
  writeFileSync(path.join(d, 'cobol', 'src', 'fresh_core.cob'), 'INSERT INTO fresh_audit (id) VALUES (?)\n');
  run(BUILD, d, ['--write']);
  assert.match(runFail(CHECK, d), /NEW L0\/L1/);
});

test('check fails on stale entry (module now linked)', () => {
  const d = makeRoot();
  run(BUILD, d, ['--write']);
  run(BUILD, d, ['--write-baseline']);
  // orphan_core gains a ledger reference + suite: L0 -> L2, baseline stale.
  writeFileSync(
    path.join(d, 'cobol', 'src', 'orphan_core.cob'),
    'INSERT INTO orphan_audit (id) VALUES (?)\nSELECT a FROM ledger WHERE id = ?\n',
  );
  writeFileSync(
    path.join(d, 'tests', 'db', 'orphan_db_tests.sh'),
    '#!/usr/bin/env bash\nrun_cobol "ORP_GET|x|||||a@b.c"\n',
  );
  run(BUILD, d, ['--write']);
  assert.match(runFail(CHECK, d), /NOW LINKED/);
});

test('check fails on unresolvable route file', () => {
  const d = makeRoot();
  run(BUILD, d, ['--write']);
  run(BUILD, d, ['--write-baseline']);
  writeFileSync(
    path.join(d, 'middleware', 'src', 'routes', 'ghost.js'),
    "export const G = [\n  { method: 'get', path: '/ghost', action: 'ZZZ_NOPE', fields: [] },\n];\n",
  );
  run(BUILD, d, ['--write']);
  assert.match(runFail(CHECK, d), /NO RESOLVABLE/);
});

test('unknown flag exits 2', () => {
  const d = makeRoot();
  for (const gate of [BUILD, CHECK]) {
    try {
      run(gate, d, ['--bogus']);
    } catch (e) {
      assert.match(String(e.status), /2/);
      continue;
    }
    assert.fail(`expected failure for ${gate} --bogus`);
  }
  assert.ok(existsSync(BUILD));
});
