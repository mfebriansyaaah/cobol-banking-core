// Unit tests for scripts/check_test_counts.mjs. No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_test_counts.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeRoot({ baseline, tsvRows = null, junit = null, dbFiles = null, caseLines = null }) {
  const d = mkdtempSync(path.join(tmpdir(), 'counts-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'tests', 'db'), { recursive: true });
  writeFileSync(path.join(d, 'tests', 'baseline_counts.txt'), baseline);
  if (tsvRows !== null) {
    const tsv = ['suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard', ...tsvRows].join('\n') + '\n';
    const art = path.join(d, 'artifacts');
    mkdirSync(art, { recursive: true });
    writeFileSync(path.join(art, 'report.tsv'), tsv);
    if (junit !== null) writeFileSync(path.join(art, 'junit-x.xml'), junit);
  }
  if (dbFiles !== null) {
    for (const [name, body] of Object.entries(dbFiles)) {
      writeFileSync(path.join(d, 'tests', 'db', name), body);
    }
  }
  if (caseLines !== null) {
    const cd = path.join(d, 'tests', 'cobol', 'cases');
    mkdirSync(cd, { recursive: true });
    writeFileSync(path.join(cd, 'a.cases'), `${caseLines.join('\n')}\n`);
  }
  return d;
}

function run(root, args, reportDir = null) {
  const a = [GATE, '--root', root];
  if (reportDir === 'static') a.push('--static');
  else a.push('--report-dir', reportDir ?? path.join(root, 'artifacts'));
  a.push(...args);
  return execFileSync(process.execPath, a, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

function runFail(root, args, reportDir = null) {
  try {
    run(root, args, reportDir);
  } catch (e) {
    return String((e && e.stderr) || e);
  }
  assert.fail(`expected failure for ${args.join(' ')}`);
  return '';
}

const BASE = 'cobol_table_tests=5\ndb_account_tests=13\ndb_schema_tests=76\ngateway_tests=4\n';
const TSV = [
  'table_runner.sh\tpass\t5\t0\t5\t10\ttable',
  'account_db_tests.sh\tpass\t13\t0\t13\t20\tserial',
  'schema_tests.sh\tpass\t76\t0\t76\t30\tserial',
];
const JUNIT = '<?xml version="1.0"?><testsuites><testcase name="a"/><testcase name="b"/><testcase name="c"/><testcase name="d"/></testsuites>';

test('matching runtime report passes', () => {
  const d = makeRoot({ baseline: BASE, tsvRows: TSV, junit: JUNIT });
  const out = run(d, ['--strict']);
  assert.match(out, /OK: 3 suite key\(s\), 94 assertion\(s\) match/);
});

test('drift fails', () => {
  const rows = TSV.map((r) => (r.startsWith('account_db') ? 'account_db_tests.sh\tpass\t12\t0\t12\t20\tserial' : r));
  const d = makeRoot({ baseline: BASE, tsvRows: rows, junit: JUNIT });
  assert.match(runFail(d, []), /db_account_tests: baseline=13 actual=12/);
});

test('missing key fails only with --strict', () => {
  const short = TSV.filter((r) => !r.startsWith('schema_tests'));
  const d = makeRoot({ baseline: BASE, tsvRows: short, junit: JUNIT });
  run(d, []); // warns, passes
  assert.match(runFail(d, ['--strict']), /db_schema_tests \(baseline 76\)/);
});

test('unlisted suite always fails', () => {
  const rows = [...TSV, 'zzz_db_tests.sh\tpass\t3\t0\t3\t5\tserial'];
  const d = makeRoot({ baseline: BASE, tsvRows: rows, junit: JUNIT });
  assert.match(runFail(d, []), /zzz/);
  assert.match(runFail(d, ['--strict']), /zzz/);
});

test('zero total fails', () => {
  const rows = TSV.map((r) => (r.startsWith('account_db') ? 'account_db_tests.sh\tmissing\t0\t0\t0\t5\tserial' : r));
  const d = makeRoot({ baseline: BASE, tsvRows: rows, junit: JUNIT });
  assert.match(runFail(d, []), /ZERO-ASSERTION/);
});

test('missing TAP summary is a missing row, not a silent pass', () => {
  const rows = TSV.map((r) => (r.startsWith('account_db') ? 'account_db_tests.sh\tmissing\t0\t0\t0\t5\tserial' : r));
  const d = makeRoot({ baseline: BASE, tsvRows: rows, junit: JUNIT });
  assert.match(runFail(d, ['--strict']), /ZERO-ASSERTION|missing/);
});

test('smoke rows are ignored, not unlisted', () => {
  const rows = [...TSV, 'smoke\tpass\t1\t0\t1\t0\tfast'];
  const d = makeRoot({ baseline: BASE, tsvRows: rows, junit: JUNIT });
  run(d, ['--strict']);
});

test('--write updates drifted values and adds new keys', () => {
  const rows = [
    'table_runner.sh\tpass\t7\t0\t7\t10\ttable',
    'account_db_tests.sh\tpass\t13\t0\t13\t20\tserial',
    'schema_tests.sh\tpass\t76\t0\t76\t30\tserial',
    'newthing_db_tests.sh\tpass\t9\t0\t9\t5\tserial',
  ];
  const d = makeRoot({ baseline: BASE, tsvRows: rows, junit: JUNIT });
  run(d, ['--write']);
  const after = readFileSync(path.join(d, 'tests', 'baseline_counts.txt'), 'utf8');
  assert.match(after, /^cobol_table_tests=7$/m);
  assert.match(after, /^db_newthing_tests=9$/m);
  assert.match(after, /^db_account_tests=13$/m);
  // second run is green
  run(d, ['--strict']);
});

test('gateway without JUnit passes without --strict, fails with it', () => {
  const d = makeRoot({ baseline: BASE, tsvRows: TSV, junit: null });
  const out = run(d, []);
  assert.match(out, /OK: 3 suite key/);
  assert.match(runFail(d, ['--strict']), /gateway_tests \(baseline 4/);
});

test('missing report.tsv fails closed', () => {
  const d = makeRoot({ baseline: BASE, tsvRows: null, junit: null });
  assert.match(runFail(d, []), /missing .*report\.tsv/);
});

test('--write updates gateway_tests from JUnit alone', () => {
  const gd = makeRoot({ baseline: BASE, tsvRows: null, junit: JUNIT });
  run(gd, ['--write']);
  const content = readFileSync(path.join(gd, 'tests', 'baseline_counts.txt'), 'utf8');
  assert.match(content, /^gateway_tests=4$/m);
  assert.match(content, /^db_account_tests=13$/m);
});

test('--write keeps keys missing from this run', () => {
  const short = TSV.filter((r) => !r.startsWith('schema_tests'));
  const d = makeRoot({ baseline: BASE, tsvRows: short, junit: JUNIT });
  run(d, ['--write']);
  const after = readFileSync(path.join(d, 'tests', 'baseline_counts.txt'), 'utf8');
  assert.match(after, /^db_schema_tests=76$/m);
});

test('static mode counts lines and skips gateway', () => {
  const dbFiles = {
    'account_db_tests.sh': '#!/usr/bin/env bash\nassert_match "a" "x" "y"\nassert_match "b" "x" "y"\n',
    'schema_tests.sh': '#!/usr/bin/env bash\nassert_match "a" "x" "y"\n',
  };
  const d = makeRoot({
    baseline: 'db_account_tests=2\ndb_schema_tests=76\ncobol_table_tests=3\n',
    dbFiles,
    caseLines: ['a@@b@@c|x', '# comment', '', 'd@@e@@f|y', 'g@@h@@i|z'],
  });
  const out = run(d, [], 'static');
  assert.match(out, /OK: 3 suite key\(s\), 6 assertion\(s\) match/);
  assert.match(out, /loop-generated/);
});

test('static mode detects deleted assertions (p7 shape)', () => {
  const dbFiles = {
    'account_db_tests.sh': '#!/usr/bin/env bash\nassert_match "a" "x" "y"\n',
    'schema_tests.sh': '#!/usr/bin/env bash\nassert_match "a" "x" "y"\n',
  };
  const d = makeRoot({
    baseline: 'db_account_tests=2\ndb_schema_tests=76\ncobol_table_tests=1\n',
    dbFiles,
    caseLines: ['a@@b@@c|x'],
  });
  assert.match(runFail(d, [], 'static'), /db_account_tests: baseline=2 actual=1/);
});
