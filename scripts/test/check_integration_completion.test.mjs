// Unit tests for scripts/check_integration_completion.mjs. No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_integration_completion.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

// Fixture: linked_core (writes ledger + wired table + suite => only the
// manual audit item stays OPEN) and gap_core (unwired write + unwired table).
function makeRoot() {
  const d = mkdtempSync(path.join(tmpdir(), 'intcomp-'));
  dirs.push(d);
  const manifest = path.join(d, 'manifest');
  mkdirSync(manifest, { recursive: true });
  writeFileSync(
    path.join(manifest, 'tier1.json'),
    JSON.stringify({
      tier1Modules: [],
      businessTables: ['ledger'],
      moneyTables: ['ledger'],
      moneyActions: ['TRANSFER'],
    }),
  );
  writeFileSync(
    path.join(manifest, 'tier1_links.json'),
    JSON.stringify({
      modules: [
        {
          module: 'linked_core',
          source: 'linked_core.cob',
          linkageLevel: 'L2',
          businessTables: ['ledger'],
          routeFiles: [],
          hasTests: true,
        },
        {
          module: 'gap_core',
          source: 'gap_core.cob',
          linkageLevel: 'L2',
          businessTables: [],
          routeFiles: [],
          hasTests: true,
        },
      ],
    }),
  );
  const cobolDir = path.join(d, 'cobol', 'src');
  mkdirSync(cobolDir, { recursive: true });
  writeFileSync(
    path.join(cobolDir, 'linked_core.cob'),
    [
      '        ACTION-POST.',
      '            MOVE "INSERT INTO ledger (id) VALUES (?)" TO WS-PREP-SQL',
      '            EXIT PARAGRAPH.',
    ].join('\n') + '\n',
  );
  writeFileSync(
    path.join(cobolDir, 'gap_core.cob'),
    [
      '        ACTION-CREATE.',
      '            MOVE "INSERT INTO gap_widget (id) VALUES (?)" TO WS-PREP-SQL',
      '            EXIT PARAGRAPH.',
    ].join('\n') + '\n',
  );
  const migDir = path.join(d, 'database', 'migrations');
  mkdirSync(migDir, { recursive: true });
  writeFileSync(
    path.join(migDir, '0001_demo.sql'),
    'CREATE TABLE IF NOT EXISTS gap_widget (id INT PRIMARY KEY, note VARCHAR(10)) ENGINE=InnoDB;\n',
  );
  const db = path.join(d, 'tests', 'db');
  mkdirSync(db, { recursive: true });
  writeFileSync(path.join(db, 'linked_db_tests.sh'), '#!/usr/bin/env bash\nrun_cobol "LNK_POST|x|||||a@b.c"\n');
  writeFileSync(path.join(db, 'gap_db_tests.sh'), '#!/usr/bin/env bash\nrun_cobol "GAP_CREATE|x|||||a@b.c"\n');
  mkdirSync(path.join(d, 'docs'), { recursive: true });
  return d;
}

function run(root, extra = []) {
  return execFileSync(process.execPath, [GATE, '--root', root, ...extra], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function runFail(root, extra = []) {
  try {
    run(root, extra);
  } catch (e) {
    return String((e && e.stderr) || e);
  }
  assert.fail(`expected failure for ${extra.join(' ')}`);
  return '';
}

function items(d) {
  return JSON.parse(readFileSync(path.join(d, 'manifest', 'integration_backlog.json'), 'utf8')).items;
}

test('--write records action + table + audit gaps', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const ids = new Set(items(d).map((i) => i.id));
  assert.ok(ids.has('gap_core:action:action-create'), 'unwired write action recorded');
  assert.ok(ids.has('gap_core:table:gap-widget'), 'unwired table recorded');
  assert.ok(ids.has('gap_core:audit:core-reference'), 'manual audit item recorded');
  assert.ok(ids.has('linked_core:audit:core-reference'), 'linked module keeps only audit item');
  assert.ok(![...ids].some((id) => id.startsWith('linked_core:action:')), 'core-linked action not listed');
  assert.ok(![...ids].some((id) => id.startsWith('linked_core:table:')), 'no domain tables, no table items');
});

test('--check passes on generated backlog', () => {
  const d = makeRoot();
  run(d, ['--write']);
  assert.match(run(d, ['--check']), /OK: integration backlog holds/);
});

test('unlisted open item fails', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'integration_backlog.json'), 'utf8'));
  data.items = data.items.filter((i) => i.id !== 'gap_core:table:gap-widget');
  writeFileSync(path.join(d, 'manifest', 'integration_backlog.json'), JSON.stringify(data));
  assert.match(runFail(d), /unlisted open item gap_core:table:gap-widget/);
});

test('stale OPEN item fails', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'integration_backlog.json'), 'utf8'));
  data.items.push({
    id: 'gap_core:action:action-gone',
    module: 'gap_core',
    kind: 'action',
    subject: 'ACTION-GONE',
    status: 'OPEN',
    reason: 'r',
    evidence: [],
    owner: null,
  });
  writeFileSync(path.join(d, 'manifest', 'integration_backlog.json'), JSON.stringify(data));
  assert.match(runFail(d), /stale item gap_core:action:action-gone/);
});

test('DONE without owner or evidence fails', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'integration_backlog.json'), 'utf8'));
  const item = data.items.find((i) => i.id === 'gap_core:table:gap-widget');
  item.status = 'DONE';
  writeFileSync(path.join(d, 'manifest', 'integration_backlog.json'), JSON.stringify(data));
  assert.match(runFail(d), /requires owner \+ evidence/);
});

test('DONE with owner and evidence passes and survives recompute', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'integration_backlog.json'), 'utf8'));
  const item = data.items.find((i) => i.id === 'gap_core:table:gap-widget');
  item.status = 'DONE';
  item.owner = 'owner@example.com';
  item.evidence = ['added account_id FK in migration 0002'];
  writeFileSync(path.join(d, 'manifest', 'integration_backlog.json'), JSON.stringify(data));
  assert.match(run(d, ['--check']), /OK:/);
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
