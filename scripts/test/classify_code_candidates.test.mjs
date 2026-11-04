// Unit tests for scripts/classify_code_candidates.mjs. No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'classify_code_candidates.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

// Fixture: two FROZEN modules (one clone-like, one custom) + one ACTIVE.
function makeRoot() {
  const d = mkdtempSync(path.join(tmpdir(), 'codecand-'));
  dirs.push(d);
  const manifest = path.join(d, 'manifest');
  mkdirSync(manifest, { recursive: true });
  writeFileSync(
    path.join(manifest, 'tier1_links.json'),
    JSON.stringify({
      modules: [
        { module: 'dup_core', linkageLevel: 'L0', businessTables: [], routeFiles: [], reason: 't' },
        { module: 'cust_core', linkageLevel: 'L0', businessTables: [], routeFiles: [], reason: 't' },
        { module: 'live_core', linkageLevel: 'L3', businessTables: [], routeFiles: [], reason: 't' },
      ],
    }),
  );
  writeFileSync(
    path.join(manifest, 'domain_status.json'),
    JSON.stringify({
      entries: [
        { module: 'dup_core', status: 'FROZEN', linkageLevel: 'L0', table: 'dup', replacement: null, reason: 'r' },
        { module: 'cust_core', status: 'FROZEN', linkageLevel: 'L0', table: null, replacement: null, reason: 'r' },
        { module: 'live_core', status: 'ACTIVE', linkageLevel: 'L3', table: null, replacement: null, reason: 'r' },
      ],
    }),
  );
  const cobolDir = path.join(d, 'cobol', 'src');
  mkdirSync(cobolDir, { recursive: true });
  writeFileSync(path.join(cobolDir, 'dup_core.cob'), 'SELECT a FROM dup WHERE id = ?\n');
  writeFileSync(path.join(cobolDir, 'cust_core.cob'), 'SELECT a FROM cust WHERE id = ?\n');
  mkdirSync(path.join(d, 'middleware', 'src', 'routes'), { recursive: true });
  mkdirSync(path.join(d, 'tests'), { recursive: true });
  writeFileSync(path.join(d, 'tests', 'clone_baseline.txt'), 'dup_core lines=10 shape=OTHER sim=0.95 level=L0\n');
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

function candidates(d) {
  return JSON.parse(readFileSync(path.join(d, 'manifest', 'code_candidates.json'), 'utf8')).candidates;
}

test('--write creates DUPLICATE + UNLINKED candidates', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const byModule = new Map(candidates(d).map((c) => [c.module, c]));
  assert.equal(byModule.size, 2);
  assert.match(byModule.get('dup_core').reason, /^DUPLICATE/);
  assert.match(byModule.get('cust_core').reason, /^UNLINKED/);
  assert.equal(byModule.get('dup_core').status, 'CANDIDATE');
  assert.equal(byModule.get('dup_core').trafficLastSeen, null);
  assert.ok(byModule.get('dup_core').evidence.length >= 4);
  assert.ok(existsSync(path.join(d, 'docs', 'CODE_CANDIDATES.md')));
  assert.ok(existsSync(path.join(d, 'tests', 'code_candidates_baseline.txt')));
});

test('--write preserves manual transitions', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'code_candidates.json'), 'utf8'));
  const dup = data.candidates.find((c) => c.module === 'dup_core');
  dup.status = 'DEPRECATED';
  dup.ownerSignoff = 'owner@example.com';
  dup.trafficLastSeen = '2026-11-01T00:00:00Z: zero traffic 90d';
  writeFileSync(path.join(d, 'manifest', 'code_candidates.json'), JSON.stringify(data));
  const out = run(d, ['--write']);
  assert.match(out, /\+0 new/);
  assert.equal(candidates(d).find((c) => c.module === 'dup_core').status, 'DEPRECATED');
});

test('--check passes on generated registry', () => {
  const d = makeRoot();
  run(d, ['--write']);
  assert.match(run(d, ['--check']), /OK: 2 code candidates/);
});

test('FROZEN module without candidate fails', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'code_candidates.json'), 'utf8'));
  data.candidates = data.candidates.filter((c) => c.module !== 'cust_core');
  writeFileSync(path.join(d, 'manifest', 'code_candidates.json'), JSON.stringify(data));
  assert.match(runFail(d), /FROZEN module without candidate: cust_core/);
});

test('non-FROZEN candidate fails', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'code_candidates.json'), 'utf8'));
  data.candidates.push({
    module: 'live_core',
    domain: 'live',
    linkageLevel: 'L3',
    reason: 'x',
    evidence: ['e'],
    trafficLastSeen: null,
    consumer: null,
    replacement: null,
    ownerSignoff: null,
    status: 'CANDIDATE',
  });
  writeFileSync(path.join(d, 'manifest', 'code_candidates.json'), JSON.stringify(data));
  assert.match(runFail(d), /not FROZEN/);
});

test('CANDIDATE with premature sign-off fails', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'code_candidates.json'), 'utf8'));
  data.candidates.find((c) => c.module === 'dup_core').ownerSignoff = 'early@example.com';
  writeFileSync(path.join(d, 'manifest', 'code_candidates.json'), JSON.stringify(data));
  assert.match(runFail(d), /must not carry ownerSignoff/);
});

test('DEPRECATED without evidence fails', () => {
  const d = makeRoot();
  run(d, ['--write']);
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'code_candidates.json'), 'utf8'));
  const dup = data.candidates.find((c) => c.module === 'dup_core');
  dup.status = 'DEPRECATED';
  writeFileSync(path.join(d, 'manifest', 'code_candidates.json'), JSON.stringify(data));
  assert.match(runFail(d), /requires ownerSignoff/);
});

test('unlisted candidate fails baseline', () => {
  const d = makeRoot();
  run(d, ['--write']);
  // A new FROZEN module + candidate added without baseline review.
  const status = JSON.parse(readFileSync(path.join(d, 'manifest', 'domain_status.json'), 'utf8'));
  status.entries.push({
    module: 'extra_core',
    status: 'FROZEN',
    linkageLevel: 'L0',
    table: null,
    replacement: null,
    reason: 'r',
  });
  writeFileSync(path.join(d, 'manifest', 'domain_status.json'), JSON.stringify(status));
  writeFileSync(path.join(d, 'cobol', 'src', 'extra_core.cob'), 'SELECT a FROM extra WHERE id = ?\n');
  const data = JSON.parse(readFileSync(path.join(d, 'manifest', 'code_candidates.json'), 'utf8'));
  data.candidates.push({
    module: 'extra_core',
    domain: 'extra',
    linkageLevel: 'L0',
    reason: 'x',
    evidence: ['e'],
    trafficLastSeen: null,
    consumer: null,
    replacement: null,
    ownerSignoff: null,
    status: 'CANDIDATE',
  });
  writeFileSync(path.join(d, 'manifest', 'code_candidates.json'), JSON.stringify(data));
  assert.match(runFail(d), /not in baseline/);
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
