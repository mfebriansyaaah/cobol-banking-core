// Unit tests for scripts/classify_domains.mjs. No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'classify_domains.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

// Fixture: tier1 + links with one module per level, small COBOL sources for
// the table heuristic, and one route file.
function makeRoot() {
  const d = mkdtempSync(path.join(tmpdir(), 'domstatus-'));
  dirs.push(d);
  const manifest = path.join(d, 'manifest');
  mkdirSync(manifest, { recursive: true });
  writeFileSync(
    path.join(manifest, 'tier1.json'),
    JSON.stringify({ tier1Modules: ['core_core'], utilityModules: ['util_core'] }),
  );
  const links = [
    { module: 'core_core', linkageLevel: 'L3', businessTables: [], routeFiles: [] },
    { module: 'linked_core', linkageLevel: 'L2', businessTables: ['ledger'], routeFiles: ['linked.js'] },
    { module: 'weak_core', linkageLevel: 'L1', businessTables: [], routeFiles: [] },
    { module: 'orphan_core', linkageLevel: 'L0', businessTables: [], routeFiles: [] },
    { module: 'util_core', linkageLevel: 'UTILITY', businessTables: [], routeFiles: [] },
  ];
  writeFileSync(path.join(manifest, 'tier1_links.json'), JSON.stringify({ modules: links }));
  const cobolDir = path.join(d, 'cobol', 'src');
  mkdirSync(cobolDir, { recursive: true });
  writeFileSync(path.join(cobolDir, 'linked_core.cob'), 'SELECT a FROM widget WHERE id = ?\n');
  writeFileSync(path.join(cobolDir, 'orphan_core.cob'), 'SELECT a FROM orphan WHERE id = ?\n');
  const routes = path.join(d, 'middleware', 'src', 'routes');
  mkdirSync(routes, { recursive: true });
  writeFileSync(path.join(routes, 'linked.js'), "export const R = [{ method: 'get', path: '/x', action: 'X' }];\n");
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

function entries(d) {
  return JSON.parse(readFileSync(path.join(d, 'manifest', 'domain_status.json'), 'utf8')).entries;
}

test('--write creates rule-based defaults', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const byModule = new Map(entries(d).map((e) => [e.module, e]));
  assert.equal(byModule.get('core_core').status, 'ACTIVE');
  assert.equal(byModule.get('linked_core').status, 'PILOT');
  assert.equal(byModule.get('weak_core').status, 'REVIEW');
  assert.equal(byModule.get('orphan_core').status, 'FROZEN');
  assert.equal(byModule.get('util_core').status, 'ACTIVE');
  assert.equal(byModule.get('linked_core').table, 'widget');
  assert.equal(byModule.get('linked_core').tier, 2);
  assert.equal(byModule.get('core_core').tier, 1);
  assert.equal(byModule.get('util_core').tier, 3);
  assert.deepEqual(byModule.get('linked_core').linkedCoreDomains, ['wallet/ledger']);
  assert.ok(existsSync(path.join(d, 'docs', 'DOMAIN_STATUS.md')));
});

test('--write preserves manual edits and only adds missing', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'domain_status.json'), 'utf8'));
  data.entries.find((e) => e.module === 'orphan_core').owner = 'reviewer@example.com';
  writeFileSync(path.join(d, 'manifest', 'domain_status.json'), JSON.stringify(data));
  const out = run(d, ['--write']);
  assert.match(out, /\+0 new/);
  assert.equal(entries(d).find((e) => e.module === 'orphan_core').owner, 'reviewer@example.com');
});

test('--check passes on generated registry', () => {
  const d = makeRoot();
  run(d, ['--write']);
  assert.match(run(d, ['--check']), /OK: 5 domain dispositions/);
});

test('missing module entry fails', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'domain_status.json'), 'utf8'));
  data.entries = data.entries.filter((e) => e.module !== 'orphan_core');
  writeFileSync(path.join(d, 'manifest', 'domain_status.json'), JSON.stringify(data));
  assert.match(runFail(d), /missing domain_status entry for module orphan_core/);
});

test('linkage mismatch fails', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'domain_status.json'), 'utf8'));
  data.entries.find((e) => e.module === 'orphan_core').linkageLevel = 'L2';
  writeFileSync(path.join(d, 'manifest', 'domain_status.json'), JSON.stringify(data));
  assert.match(runFail(d), /linkageLevel L2 != tier1_links L0/);
});

test('L0 ACTIVE fails', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'domain_status.json'), 'utf8'));
  data.entries.find((e) => e.module === 'orphan_core').status = 'ACTIVE';
  writeFileSync(path.join(d, 'manifest', 'domain_status.json'), JSON.stringify(data));
  assert.match(runFail(d), /must not be ACTIVE/);
});

test('RETIRED with active route fails; without route passes', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'domain_status.json'), 'utf8'));
  const orphan = data.entries.find((e) => e.module === 'orphan_core');
  orphan.status = 'RETIRED';
  orphan.replacement = 'linked_core';
  orphan.trafficLastSeen = '2026-11-01T00:00:00Z: no traffic in 90d';
  writeFileSync(path.join(d, 'manifest', 'domain_status.json'), JSON.stringify(data));
  assert.match(run(d, ['--check']), /OK:/);
  // Now point it at an existing route file: must fail.
  orphan.routeFile = 'linked.js';
  writeFileSync(path.join(d, 'manifest', 'domain_status.json'), JSON.stringify(data));
  assert.match(runFail(d), /still active/);
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
