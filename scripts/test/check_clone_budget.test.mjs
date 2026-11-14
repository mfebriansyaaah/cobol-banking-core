// Unit tests for scripts/check_clone_budget.mjs. No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { TEMPLATE_LINES } from '../lib/clone_template.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_clone_budget.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

const ACTIONS_9 = ['CREATE', 'LIST', 'GET', 'CALC', 'UPDATE', 'DELETE', 'SUMMARY', 'AUDIT', 'VALIDATE']
  .map((s) => {
    const name = `TST_${s}`;
    return `               WHEN LS-CMD-ACTION(1:${name.length}) = "${name}"`;
  })
  .join('\n');

// Minimal tree: template + exact-copy clone (L0) + hand-written module.
// templateLines controls the template size; clones copy it verbatim.
function makeRoot({ templateLines = 20, baseline = true } = {}) {
  const d = mkdtempSync(path.join(tmpdir(), 'clonebud-'));
  dirs.push(d);
  const cobolDir = path.join(d, 'cobol', 'src');
  mkdirSync(cobolDir, { recursive: true });
  const template = ['IDENTIFICATION DIVISION.', 'PROGRAM-ID. tpl.', ACTIONS_9].join('\n');
  const pad = Array.from({ length: templateLines }, (_, i) => `      *> template line ${i}.`).join('\n');
  writeFileSync(path.join(cobolDir, 'cost_center_core.cob'), `${template}\n${pad}\n`);
  writeFileSync(
    path.join(cobolDir, 'clone_core.cob'),
    readFileSync(path.join(cobolDir, 'cost_center_core.cob'), 'utf8'),
  );
  writeFileSync(
    path.join(cobolDir, 'hand_core.cob'),
    'IDENTIFICATION DIVISION.\nPROGRAM-ID. hand.\n       MOVE 1 TO X.\n',
  );
  writeFileSync(path.join(cobolDir, 'main_logic.cob'), 'IDENTIFICATION DIVISION.\n');
  const manifest = path.join(d, 'manifest');
  mkdirSync(manifest, { recursive: true });
  writeFileSync(
    path.join(manifest, 'tier1_links.json'),
    JSON.stringify({
      modules: [
        { module: 'clone_core', linkageLevel: 'L0' },
        { module: 'hand_core', linkageLevel: 'L2' },
      ],
    }),
  );
  mkdirSync(path.join(d, 'tests'), { recursive: true });
  if (baseline) {
    const lines = readFileSync(path.join(cobolDir, 'clone_core.cob'), 'utf8').split('\n').length - 1;
    writeFileSync(
      path.join(d, 'tests', 'clone_baseline.txt'),
      `clone_core lines=${lines} shape=OTHER sim=1.00 level=L0\n`,
    );
  } else {
    writeFileSync(path.join(d, 'tests', 'clone_baseline.txt'), '# empty\n');
  }
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

test('recorded clone passes', () => {
  const d = makeRoot();
  assert.match(run(d), /OK: 1 clone-like L0\/L1/);
});

test('new clone-shaped L0 module fails', () => {
  const d = makeRoot();
  writeFileSync(
    path.join(d, 'cobol', 'src', 'fresh_core.cob'),
    readFileSync(path.join(d, 'cobol', 'src', 'cost_center_core.cob'), 'utf8'),
  );
  const manifest = JSON.parse(readFileSync(path.join(d, 'manifest', 'tier1_links.json'), 'utf8'));
  manifest.modules.push({ module: 'fresh_core', linkageLevel: 'L0' });
  writeFileSync(path.join(d, 'manifest', 'tier1_links.json'), JSON.stringify(manifest));
  assert.match(runFail(d), /NEW CLONES/);
});

test('new template-sized module fails even without clone shape', () => {
  const d = makeRoot();
  const pad = Array.from({ length: TEMPLATE_LINES - 1 }, (_, i) => `      *> filler ${i}.`).join('\n');
  writeFileSync(path.join(d, 'cobol', 'src', 'big_core.cob'), `IDENTIFICATION DIVISION.\n${pad}\n`);
  const manifest = JSON.parse(readFileSync(path.join(d, 'manifest', 'tier1_links.json'), 'utf8'));
  manifest.modules.push({ module: 'big_core', linkageLevel: 'L1' });
  writeFileSync(path.join(d, 'manifest', 'tier1_links.json'), JSON.stringify(manifest));
  assert.match(runFail(d), /NEW CLONES/);
});

test('clone-shaped L2 module warns but passes', () => {
  const d = makeRoot();
  const manifest = JSON.parse(readFileSync(path.join(d, 'manifest', 'tier1_links.json'), 'utf8'));
  manifest.modules.find((m) => m.module === 'clone_core').linkageLevel = 'L2';
  writeFileSync(path.join(d, 'manifest', 'tier1_links.json'), JSON.stringify(manifest));
  // Baseline still records L0 -> stale failure proves the level change is
  // noticed; rewrite baseline via --write first, then it warns and passes.
  run(d, ['--write']);
  const combined = spawnSync(process.execPath, [GATE, '--root', d], { encoding: 'utf8' });
  assert.equal(combined.status, 0);
  assert.match(combined.stderr, /reviewer should confirm/);
  assert.match(combined.stdout, /OK:/);
});

test('--write drops stale entries and reports counts', () => {
  const d = makeRoot();
  const manifest = JSON.parse(readFileSync(path.join(d, 'manifest', 'tier1_links.json'), 'utf8'));
  manifest.modules.find((m) => m.module === 'clone_core').linkageLevel = 'L3';
  writeFileSync(path.join(d, 'manifest', 'tier1_links.json'), JSON.stringify(manifest));
  const out = run(d, ['--write']);
  assert.match(out, /total 0/);
  const ok = run(d);
  assert.match(ok, /OK:/);
});

test('stale entry fails (module now linked)', () => {
  const d = makeRoot();
  const manifest = JSON.parse(readFileSync(path.join(d, 'manifest', 'tier1_links.json'), 'utf8'));
  manifest.modules.find((m) => m.module === 'clone_core').linkageLevel = 'L2';
  writeFileSync(path.join(d, 'manifest', 'tier1_links.json'), JSON.stringify(manifest));
  assert.match(runFail(d), /NO LONGER CLONE-LIKE/);
});

test('dead entry fails (module removed)', () => {
  const d = makeRoot();
  rmSync(path.join(d, 'cobol', 'src', 'clone_core.cob'));
  assert.match(runFail(d), /NO MODULE/);
});

test('malformed baseline line fails', () => {
  const d = makeRoot();
  writeFileSync(path.join(d, 'tests', 'clone_baseline.txt'), 'not a valid line\n');
  assert.match(runFail(d), /malformed/);
});

test('duplicate baseline entries fail', () => {
  const d = makeRoot();
  const cur = readFileSync(path.join(d, 'tests', 'clone_baseline.txt'), 'utf8');
  writeFileSync(path.join(d, 'tests', 'clone_baseline.txt'), `${cur}${cur}`);
  assert.match(runFail(d), /duplicate/i);
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
