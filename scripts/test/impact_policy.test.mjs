// Unit tests for scripts/ci/impact-policy.mjs (PR-01).
// Pure mapping: no database, no build, no git. Every canonical policy row
// (§3 of the master plan) has at least one case; multi-file merges, coverage
// conditionals, and the tracked-tree audit pin the fail-safe behavior.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { classifyFile, planForFiles } from '../ci/impact-policy.mjs';

const SUITES = new Set(['loan_db_tests', 'account_db_tests']);
const MODULES = new Set(['loan_core', 'account_core']);

function plan(file) {
  const c = classifyFile(file);
  assert.ok(c.plan, `missing plan for ${file}`);
  return c;
}

test('docs paths map to docs-only', () => {
  for (const f of [
    'docs/CI.md',
    'README.md',
    'CONTRIBUTING.md',
    'SECURITY.md',
    'CHANGELOG.md',
    'LICENSE',
    '.github/ISSUE_TEMPLATE/bug_report.md',
    '.github/pull_request_template.md',
    '.github/CODEOWNERS',
  ]) {
    const c = plan(f);
    assert.equal(c.mode, 'docs', f);
    assert.equal(c.plan.lint, 'docs', f);
    assert.equal(c.plan.build, false, f);
    assert.equal(c.plan.test, 'none', f);
    assert.equal(c.plan.db, 'none', f);
    assert.equal(c.unmapped, false, f);
  }
});

test('coverage data maps to coverage-only', () => {
  for (const f of ['tests/coverage_baseline.txt', 'tests/coverage_floor_backlog.txt']) {
    const c = plan(f);
    assert.equal(c.mode, 'coverage', f);
    assert.equal(c.plan.cobol_coverage, true, f);
    assert.equal(c.plan.build, false, f);
    assert.equal(c.plan.test, 'none', f);
  }
});

test('static registries and baselines never trigger runtime', () => {
  for (const f of [
    'manifest/modules.json',
    'manifest/domain_status.json',
    'contracts/actions.yaml',
    'contracts/errors.yaml',
    'tests/README.md',
    'tests/baseline_counts.txt',
    'tests/warning_baseline.txt',
    'tests/code_candidates_baseline.txt',
    'tests/counts.json',
    'tests/fixtures/script-trees/mini/tests/db/account_db_tests.sh',
    'tests/contracts/route_field_order.json',
    'tests/scripts/test_run_all_cli.sh',
    'tests/scripts/run.sh',
    'tests/perf/bench.sh',
    'tests/probes/run_probes.sh',
    'tests/.dbenv',
    'monitoring/prometheus-alerts.yml',
    'Makefile',
    'package.json',
    'package-lock.json',
    'input.txt',
    'output.txt',
    'sql_debug.log',
    '.DS_Store',
    'Thumbs.db',
    'artifacts/run-all.json',
    'backups/snapshot.sql.gz',
    'coverage/cobol.txt',
  ]) {
    const c = plan(f);
    assert.equal(c.mode, 'static', f);
    assert.equal(c.plan.build, false, f);
    assert.equal(c.plan.test, 'none', f);
    assert.equal(c.plan.db, 'none', f);
    assert.equal(c.plan.gateway_coverage, false, f);
    assert.equal(c.plan.cobol_coverage, false, f);
    assert.equal(c.plan.docker, false, f);
  }
});

test('static CI and check tooling never triggers runtime', () => {
  for (const f of [
    'scripts/check_docs.mjs',
    'scripts/test/select_tests.test.mjs',
    'scripts/ci/classify_changes.sh',
    'scripts/ci/impact-policy.mjs',
    'scripts/ci/check_ci_docs.mjs',
    'scripts/ci/shard_timings.mjs',
    'scripts/ci/aggregate_shard_reports.sh',
    'scripts/ci/summary.mjs',
    'scripts/ci/compare_runs.mjs',
    'scripts/ci/quarantine_flag.mjs',
    'scripts/ci/ci_metrics.mjs',
  ]) {
    const c = plan(f);
    assert.equal(c.mode, 'static', f);
    assert.equal(c.plan.test, 'none', f);
    assert.equal(c.plan.db, 'none', f);
  }
});

test('schema-drift helpers flag the drift job', () => {
  for (const f of ['scripts/check_schema_drift.sh', 'scripts/generate_schema_snapshot.sh']) {
    const c = plan(f);
    assert.equal(c.plan.schema_drift, true, f);
    assert.equal(c.plan.build, false, f);
  }
});

test('coverage tooling maps to coverage-only', () => {
  for (const f of ['scripts/ci/coverage.sh', 'scripts/ci/coverage_trigger.mjs', 'scripts/coverage/map_cobol.py']) {
    const c = plan(f);
    assert.equal(c.mode, 'coverage', f);
    assert.equal(c.plan.cobol_coverage, true, f);
    assert.equal(c.plan.build, false, f);
  }
});

test('migration suites select themselves plus schema drift', () => {
  const c = plan('tests/db/migration_archive_db_tests.sh');
  assert.equal(c.mode, 'code');
  assert.equal(c.plan.db, 'selected');
  assert.deepEqual(c.plan.db_suites, ['tests/db/migration_archive_db_tests.sh']);
  assert.equal(c.plan.schema_drift, true);
});

test('db suite maps to itself plus its case file', () => {
  const c = plan('tests/db/loan_db_tests.sh');
  assert.equal(c.mode, 'code');
  assert.equal(c.plan.test, 'selected');
  assert.equal(c.plan.db, 'selected');
  assert.deepEqual(c.plan.db_suites, ['tests/db/loan_db_tests.sh']);
  assert.deepEqual(c.plan.table_cases, ['tests/cobol/cases/loan.cases']);
  assert.equal(c.plan.gateway_coverage, true);
});

test('case file maps to itself plus its suite', () => {
  const c = plan('tests/cobol/cases/loan.cases');
  assert.equal(c.mode, 'code');
  assert.deepEqual(c.plan.table_cases, ['tests/cobol/cases/loan.cases']);
  assert.deepEqual(c.plan.db_suites, ['tests/db/loan_db_tests.sh']);
});

test('cobol domain maps to suite, case, and full integration', () => {
  const c = plan('cobol/src/loan_core.cob');
  assert.equal(c.mode, 'code');
  assert.equal(c.plan.build, true);
  assert.equal(c.plan.test, 'selected');
  assert.equal(c.plan.integration, 'full');
  assert.equal(c.plan.db, 'selected');
  assert.deepEqual(c.plan.db_suites, ['tests/db/loan_db_tests.sh']);
  assert.deepEqual(c.plan.table_cases, ['tests/cobol/cases/loan.cases']);
});

test('shared cobol inputs escalate to full (no image rebuild)', () => {
  for (const f of ['cobol/copy/loan-copy.cpy', 'cobol/src/sql_bridge.c', 'cobol/src/sql_bridge.h']) {
    const c = plan(f);
    assert.equal(c.mode, 'full', f);
    assert.equal(c.plan.test, 'full', f);
    assert.equal(c.plan.db, 'full', f);
    assert.equal(c.plan.docker, false, f);
  }
});

test('build inputs escalate to full plus docker', () => {
  for (const f of ['build.sh', 'cobol/Makefile', 'scripts/ci/install_gnucobol.sh']) {
    const c = plan(f);
    assert.equal(c.mode, 'full', f);
    assert.equal(c.plan.docker, true, f);
  }
});

test('database surface means full fleet plus drift', () => {
  const c = plan('database/schema.sql');
  assert.equal(c.mode, 'full');
  assert.equal(c.plan.db, 'full');
  assert.equal(c.plan.schema_drift, true);
  assert.equal(c.plan.docker, false);
});

test('gateway route selects the endpoints suite', () => {
  const c = plan('middleware/src/routes/loan.js');
  assert.equal(c.mode, 'code');
  assert.equal(c.plan.test, 'selected');
  assert.equal(c.plan.node_suite, 'endpoints');
  assert.equal(c.plan.db, 'none');
  assert.equal(c.plan.gateway_coverage, true);
});

test('gateway sources select the fast suite', () => {
  const c = plan('middleware/src/app.js');
  assert.equal(c.mode, 'code');
  assert.equal(c.plan.node_suite, 'fast');
  assert.equal(c.plan.db, 'none');
});

test('gateway deps select the full node suite plus docker', () => {
  for (const f of ['middleware/package.json', 'middleware/package-lock.json']) {
    const c = plan(f);
    assert.equal(c.plan.node_suite, 'full', f);
    assert.equal(c.plan.docker, true, f);
  }
});

test('single middleware test file maps to itself', () => {
  const c = plan('middleware/test/account.test.js');
  assert.equal(c.mode, 'code');
  assert.deepEqual(c.plan.node_files, ['middleware/test/account.test.js']);
  assert.equal(c.plan.node_suite, 'none');
});

test('field order fixture maps to its test file', () => {
  const c = plan('middleware/test/fixtures/field_order_contract.json');
  assert.deepEqual(c.plan.node_files, ['middleware/test/field_order.test.js']);
});

test('gateway support maps to the full node suite', () => {
  const c = plan('middleware/test/support.js');
  assert.equal(c.plan.node_suite, 'full');
  assert.equal(c.plan.cobol_coverage, true);
});

test('gateway smoke selects the gateway suite', () => {
  const c = plan('tests/gateway/endpoint_smoke.sh');
  assert.equal(c.plan.node_suite, 'gateway');
  assert.equal(c.plan.gateway_coverage, true);
  assert.equal(c.plan.cobol_coverage, false);
});

test('integration flow selects itself', () => {
  const c = plan('tests/integration/loan_flow.sh');
  assert.equal(c.plan.integration, 'selected');
  assert.deepEqual(c.plan.integration_flows, ['loan_flow']);
  assert.equal(c.plan.db, 'none');
});

test('test harness escalates to full', () => {
  for (const f of [
    'tests/lib/db.sh',
    'tests/fuzz/fuzz_inputs.sh',
    'tests/run_all.sh',
    'tests/cobol/table_runner.sh',
    'tests/check_cobol_c_errors.sh',
  ]) {
    const c = plan(f);
    assert.equal(c.mode, 'full', f);
    assert.equal(c.plan.test, 'full', f);
    assert.equal(c.plan.db, 'full', f);
  }
});

test('ci meta never triggers runtime', () => {
  for (const f of [
    'scripts/ci/classify_changes.sh',
    '.github/workflows/ci.yml',
    '.github/actions/db-bootstrap/action.yml',
    '.github/dependabot.yml',
  ]) {
    const c = plan(f);
    assert.equal(c.mode, 'static', f);
    assert.equal(c.plan.build, false, f);
    assert.equal(c.plan.test, 'none', f);
    assert.equal(c.plan.db, 'none', f);
  }
});

test('image definition flags docker only', () => {
  for (const f of ['Dockerfile', '.dockerignore']) {
    const c = plan(f);
    assert.equal(c.plan.docker, true, f);
    assert.equal(c.plan.build, true, f);
    assert.equal(c.plan.test, 'none', f);
  }
});

test('unknown paths fall back to full and unmapped', () => {
  for (const f of ['totally/unknown.xyz', 'foo/bar.xyz']) {
    const c = plan(f);
    assert.equal(c.mode, 'full', f);
    assert.equal(c.unmapped, true, f);
    assert.equal(c.plan.test, 'full', f);
    assert.equal(c.plan.db, 'full', f);
  }
});

test('multi-file merge takes the strongest field', () => {
  const r = planForFiles(['docs/CI.md', 'manifest/modules.json'], { suites: SUITES, modules: MODULES });
  assert.equal(r.mode, 'static');
  assert.equal(r.plan.lint, 'full');

  const code = planForFiles(['docs/CI.md', 'tests/db/loan_db_tests.sh'], { suites: SUITES, modules: MODULES });
  assert.equal(code.mode, 'code');
  assert.equal(code.plan.db, 'selected');

  const full = planForFiles(['database/schema.sql', 'tests/db/loan_db_tests.sh'], {
    suites: SUITES,
    modules: MODULES,
  });
  assert.equal(full.mode, 'full');
  assert.equal(full.plan.db, 'full');

  const unknown = planForFiles(['tests/db/loan_db_tests.sh', 'totally/unknown.xyz'], {
    suites: SUITES,
    modules: MODULES,
  });
  assert.equal(unknown.mode, 'full');
  assert.deepEqual(unknown.unmapped, ['totally/unknown.xyz']);
});

test('coverage conditionals resolve against the curated sets', () => {
  const hit = planForFiles(['tests/db/loan_db_tests.sh'], { suites: SUITES, modules: MODULES });
  assert.equal(hit.plan.cobol_coverage, true);
  const miss = planForFiles(['tests/db/loan_db_tests.sh'], { suites: new Set(), modules: MODULES });
  assert.equal(miss.plan.cobol_coverage, false);

  const curated = planForFiles(['cobol/src/loan_core.cob'], { suites: SUITES, modules: MODULES });
  assert.equal(curated.plan.cobol_coverage, true);
  const uncurated = planForFiles(['cobol/src/loan_core.cob'], { suites: SUITES, modules: new Set() });
  assert.equal(uncurated.plan.cobol_coverage, false);

  // Null sets resolve conservatively to true (cannot tell).
  const conservative = planForFiles(['cobol/src/loan_core.cob']);
  assert.equal(conservative.plan.cobol_coverage, true);
});

test('db fields are exact per category', () => {
  const cases = [
    ['docs/CI.md', 'none', []],
    ['manifest/modules.json', 'none', []],
    ['tests/coverage_baseline.txt', 'none', []],
    ['scripts/ci/impact-plan.mjs', 'none', []],
    ['.github/workflows/ci.yml', 'none', []],
    ['middleware/src/routes/loan.js', 'none', []],
    ['middleware/src/app.js', 'none', []],
    ['middleware/test/contract.test.js', 'none', []],
    ['tests/gateway/endpoint_smoke.sh', 'none', []],
    ['tests/integration/loan_flow.sh', 'none', []],
    ['tests/db/loan_db_tests.sh', 'selected', ['tests/db/loan_db_tests.sh']],
    ['tests/cobol/cases/loan.cases', 'selected', ['tests/db/loan_db_tests.sh']],
    ['cobol/src/loan_core.cob', 'selected', ['tests/db/loan_db_tests.sh']],
    ['tests/db/migration_archive_db_tests.sh', 'selected', ['tests/db/migration_archive_db_tests.sh']],
    ['database/schema.sql', 'full', []],
    ['cobol/copy/loan-copy.cpy', 'full', []],
    ['build.sh', 'full', []],
    ['tests/lib/db.sh', 'full', []],
    ['tests/run_all.sh', 'full', []],
    ['totally/unknown.xyz', 'full', []],
  ];
  for (const [file, db, suites] of cases) {
    const c = plan(file);
    assert.equal(c.plan.db, db, file);
    assert.deepEqual(c.plan.db_suites, suites, file);
  }
  const migration = plan('tests/db/migration_archive_db_tests.sh');
  assert.equal(migration.plan.schema_drift, true);
  const schema = plan('database/schema.sql');
  assert.equal(schema.plan.schema_drift, true);
  const route = plan('middleware/src/routes/loan.js');
  assert.equal(route.plan.schema_drift, false);
});

test('empty file list selects nothing', () => {
  const r = planForFiles([], { suites: SUITES, modules: MODULES });
  assert.equal(r.mode, 'docs');
  assert.equal(r.plan.test, 'none');
  assert.deepEqual(r.unmapped, []);
});

test('every tracked file maps (excluding volatile prefixes)', () => {
  const out = execFileSync('git', ['ls-files'], { encoding: 'utf8', cwd: process.cwd() });
  const excluded = ['artifacts/', 'backups/', 'coverage/', 'node_modules/', 'test-results/', 'tmp/'];
  const files = out
    .split('\n')
    .map((s) => s.trim())
    .filter((s) => s && !excluded.some((p) => s.startsWith(p)));
  assert.ok(files.length > 100, 'expected a populated tree');
  const bad = [];
  for (const f of files) {
    try {
      const c = classifyFile(f);
      if (c.unmapped) bad.push(f);
    } catch {
      bad.push(f);
    }
  }
  assert.deepEqual(bad, [], `unmapped tracked files:\n${bad.join('\n')}`);
});
