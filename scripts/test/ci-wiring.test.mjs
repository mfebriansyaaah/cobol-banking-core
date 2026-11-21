// CI wiring meta-test (T-011).
//
// Every documented test entrypoint must be referenced by at least one
// workflow `run:` step, and every tests/scripts/test_*.sh harness file must
// be executed by tests/scripts/run.sh. A new harness that nobody runs must
// fail this test instead of silently never executing.
//
// Workflow steps are parsed with python3+PyYAML (same parser as
// scripts/check_ci_contract.mjs); matching is substring-based against an
// explicit per-entrypoint needle list so indirect invocations
// (workflow -> run_all.sh -> endpoint_smoke.sh) stay documented.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

// [entrypoint, [needles...]] — at least one needle must occur in some run: step.
const WIRED = [
  ['tests/run_all.sh', ['run_all.sh']],
  ['tests/scripts/run.sh', ['tests/scripts/run.sh']],
  ['scripts/coverage/test_map_cobol.py', ['test_map_cobol.py']],
  ['tests/probes/run_probes.sh', ['run_probes.sh']],
  ['tests/probes/money_path_mutants.sh', ['money_path_mutants.sh']],
  ['tests/perf/bench.sh', ['bench.sh']],
  ['tests/perf/load_gateway.sh', ['load_gateway.sh']],
  ['tests/gateway/endpoint_smoke.sh', ['endpoint_smoke.sh', 'run_all.sh full']],
  ['scripts/test/*.test.mjs', ['test:scripts', 'scripts/test/*.test.mjs']],
  ['scripts/ci/coverage.sh', ['coverage.sh']],
  ['scripts/check_test_counts.mjs', ['check_test_counts']],
  ['scripts/check_docs.mjs', ['check_docs']],
  ['scripts/check_pr_size_policy.mjs', ['check_pr_size_policy', 'tests/run_all.sh gates']],
  ['scripts/pr_size.mjs', ['pr_size.mjs']],
  ['scripts/check_schema_drift.sh', ['check_schema_drift']],
  ['scripts/check_warnings.sh', ['check_warnings']],
  ['scripts/ci/migration_rollback_drill.sh', ['migration_rollback_drill']],
  ['scripts/ci/backup_restore_drill.sh', ['backup_restore_drill']],
  // Local-only by design (schema snapshot helper; CI covers the same ground
  // through the rollback/backup drills + drift check).
  ['scripts/ci/restore_drill.sh', ['LOCAL-ONLY']],
  ['scripts/ci/build_db_snapshot.sh', ['build_db_snapshot']],
  ['scripts/ci/classify_changes.mjs', ['classify_changes']],
  ['scripts/ci/impact-plan.mjs', ['impact-plan.mjs']],
  ['scripts/ci/impact-audit.mjs', ['impact-audit.mjs']],
  ['scripts/ci/lint_docs.sh', ['lint_docs.sh']],
];

function collectRunSteps() {
  const script = `
import json, sys, glob, yaml
out = []
for f in sorted(glob.glob('GH/.github/workflows/*.yml'.replace('GH', sys.argv[1]))):
    try:
        with open(f) as fh:
            doc = yaml.safe_load(fh.read())
    except Exception:
        continue
    for _job, spec in (doc.get('jobs') or {}).items():
        for step in (spec or {}).get('steps') or []:
            if isinstance(step, dict) and step.get('run'):
                out.append(step['run'])
print(json.dumps(out))
`;
  const stdout = execFileSync('python3', ['-c', script, ROOT], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: 60000,
  });
  return JSON.parse(stdout);
}

// Pure checker so the negative control below exercises the real logic.
function findUnwired(entries, runSteps) {
  return entries.filter((entry) => !entry[1].some((n) => runSteps.some((s) => s.includes(n)))).map(([name]) => name);
}

test('every documented entrypoint is wired into a workflow', () => {
  const runs = collectRunSteps();
  assert.ok(runs.length > 0, 'expected workflow run: steps');
  const missing = findUnwired(
    WIRED.filter(([e]) => e !== 'scripts/ci/restore_drill.sh'),
    runs,
  );
  assert.deepEqual(missing, [], `unwired test entrypoints:\n${missing.join('\n')}`);
});

test('restore_drill.sh is explicitly local-only', () => {
  const runs = collectRunSteps();
  const missing = findUnwired([['scripts/ci/restore_drill.sh', ['scripts/ci/restore_drill.sh']]], runs);
  assert.deepEqual(missing, ['scripts/ci/restore_drill.sh']);
});

test('every scripts harness test is executed by run.sh', () => {
  const harness = readFileSync(path.join(ROOT, 'tests', 'scripts', 'run.sh'), 'utf8');
  assert.match(harness, /test_\*\.sh/, 'run.sh must glob test_*.sh');
});

test('negative control: an unwired entry is reported', () => {
  const missing = findUnwired([['no/such_thing.sh', ['definitely-not-a-real-step']]], ['echo hi']);
  assert.deepEqual(missing, ['no/such_thing.sh']);
});

// CI-007: DB drills and the hardware-sensitive benchmark run on main and
// nightly, not on every PR. These tests pin the end state: a `db-ops` job in
// ci.yml owns the three checks, the PR `test` job owns none of them, the old
// `post-merge` job is gone, and the benchmark lives in nightly.
const DRILL_NEEDLES = ['migration_rollback_drill', 'backup_restore_drill'];

function collectWorkflowJobs() {
  const script = `
import json, sys, glob, os, yaml
out = {}
for f in sorted(glob.glob('GH/.github/workflows/*.yml'.replace('GH', sys.argv[1]))):
    try:
        with open(f) as fh:
            doc = yaml.safe_load(fh.read())
    except Exception:
        continue
    jobs = {}
    for job_id, spec in (doc.get('jobs') or {}).items():
        spec = spec or {}
        runs = [s['run'] for s in (spec.get('steps') or []) if isinstance(s, dict) and s.get('run')]
        jobs[job_id] = {
            'name': spec.get('name'),
            'if': spec.get('if'),
            'needs': spec.get('needs'),
            'timeout': spec.get('timeout-minutes'),
            'env': spec.get('env') or {},
            'runs': runs,
        }
    out[os.path.basename(f)] = jobs
print(json.dumps(out))
`;
  const stdout = execFileSync('python3', ['-c', script, ROOT], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: 60000,
  });
  return JSON.parse(stdout);
}

test('db-ops job runs rollback and backup drills (drift moved out)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.ok(ci['db-ops'], 'ci.yml must define a db-ops job');
  assert.equal(ci['db-ops'].name, 'db-ops');
  assert.equal(ci['db-ops'].timeout, 20);
  const runs = ci['db-ops'].runs.join('\n');
  for (const needle of DRILL_NEEDLES) {
    assert.match(runs, new RegExp(needle), `db-ops must run ${needle}`);
  }
  assert.doesNotMatch(
    runs,
    /check_schema_drift/,
    'drift must run once, in the schema-drift job (not duplicated on push)',
  );
});

test('schema-drift reuses the snapshot producer without blocking DB consumers', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.ok(ci['schema-drift'], 'ci.yml must define a schema-drift job');
  assert.equal(ci['schema-drift'].name, 'schema-drift');
  const runs = ci['schema-drift'].runs.join('\n');
  assert.match(runs, /check_schema_drift/, 'schema-drift must run the drift check');
  assert.match(
    runs,
    /--from \/tmp\/schema-fresh\/schema-fresh\.sql/,
    'schema-drift must consume the producer artifact',
  );
  const needs = Array.isArray(ci['schema-drift'].needs) ? ci['schema-drift'].needs : [ci['schema-drift'].needs];
  assert.ok(needs.includes('changes'), 'schema-drift must honor the docs-only gate');
  assert.ok(needs.includes('db-snapshot'), 'schema-drift must reuse the producer schema snapshot');

  const producerRuns = ci['db-snapshot'].runs.join('\n');
  assert.match(
    producerRuns,
    /generate_schema_snapshot\.sh --from-db/,
    'db-snapshot must emit the normalized schema snapshot',
  );
  const ciYaml = readFileSync(path.join(ROOT, '.github/workflows/ci.yml'), 'utf8');
  assert.match(ciYaml, /name: schema-fresh/, 'db-snapshot must publish the schema-fresh artifact');
  assert.doesNotMatch(
    producerRuns,
    /check_schema_drift/,
    'db-snapshot must stay a pure producer (drift check is a separate job)',
  );

  // A drift failure must not withhold the DB data snapshot from the fleet:
  // only the aggregate gate waits for schema-drift.
  for (const id of ['test', 'db-shards', 'coverage-pr']) {
    const consumerNeeds = Array.isArray(ci[id].needs) ? ci[id].needs : [ci[id].needs];
    assert.ok(!consumerNeeds.includes('schema-drift'), `${id} must not depend on schema-drift`);
  }
  const aggNeeds = Array.isArray(ci['db-aggregate'].needs) ? ci['db-aggregate'].needs : [ci['db-aggregate'].needs];
  assert.ok(aggNeeds.includes('schema-drift'), 'db aggregate must wait for schema-drift');
  const raw = readFileSync(path.join(ROOT, '.github/workflows/ci.yml'), 'utf8');
  assert.match(raw, /needs\.schema-drift\.result == 'failure'/, 'db aggregate must fail when schema-drift failed');
});

test('db-ops runs on push main and dispatch, never on PRs', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.ok(ci['db-ops'], 'ci.yml must define a db-ops job');
  const needs = Array.isArray(ci['db-ops'].needs) ? ci['db-ops'].needs : [ci['db-ops'].needs];
  assert.ok(needs.includes('build'), 'db-ops must need the build job');
  const cond = String(ci['db-ops'].if);
  assert.match(cond, /github\.event_name == 'workflow_dispatch'/, 'db-ops must stay dispatchable');
  assert.match(cond, /github\.event_name == 'push'/, 'db-ops must run on qualifying pushes');
  assert.match(cond, /db_ops_relevant/, 'db-ops must only run when the DB surface changed');
  assert.doesNotMatch(cond, /pull_request/, 'db-ops must stay excluded from pull_request');
});

test('PR test job has no drills, drift check, or benchmarks', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  const runs = ci['test'].runs.join('\n');
  for (const needle of [...DRILL_NEEDLES, 'bench.sh', 'drill-logs']) {
    assert.doesNotMatch(runs, new RegExp(needle), `test job must not contain ${needle}`);
  }
});

test('post-merge job is removed (replaced by db-ops)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.ok(!('post-merge' in ci), 'ci.yml must not define a post-merge job');
});

test('performance benchmark runs in nightly, not in the PR gate', () => {
  const all = collectWorkflowJobs();
  const nightlyJob = all['nightly.yml']['full-twice'];
  assert.ok(nightlyJob, 'nightly.yml must define the full-twice job');
  const nightlyRuns = nightlyJob.runs.join('\n');
  assert.match(nightlyRuns, /tests\/perf\/bench\.sh/, 'nightly must run the performance benchmark');
  assert.doesNotMatch(nightlyRuns, /coverage\.sh/, 'nightly must not duplicate scheduled coverage');
  const ciTestRuns = all['ci.yml']['test'].runs.join('\n');
  assert.doesNotMatch(ciTestRuns, /bench\.sh/, 'PR test job must not run the benchmark');
  const idx = (needle) => nightlyJob.runs.findIndex((s) => s.includes(needle));
  assert.ok(idx('bench.sh') >= 0 && idx('load_gateway.sh') >= 0);
  assert.ok(idx('bench.sh') < idx('load_gateway.sh'), 'benchmark must run before the load test');
});

test('static gates run once in lint; PR test skips the gate fleet', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.match(ci['lint'].runs.join('\n'), /tests\/run_all\.sh gates/, 'lint must run the full gate fleet');
  assert.equal(ci['test'].env?.SKIP_STATIC_GATES, '1', 'PR test must skip the lint-owned gate fleet');
});

test('heavy jobs gate on effective plan outputs (CI-011 option A, PR-02)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.ok(ci['changes'], 'ci.yml must define a changes job');
  const expected = {
    build: /eff_build == 'true'/,
    'db-shards': /eff_db == 'full'/,
    'db-selected': /eff_db == 'selected'/,
    'coverage-pr': /eff_cobol_coverage == 'true'/,
    coverage: /eff_gateway_coverage == 'true'/,
    'db-aggregate': /eff_aggregate == 'true'/,
    test: /eff_test != 'none'/,
    'db-snapshot': /eff_db_snapshot == 'true'/,
  };
  for (const [id, re] of Object.entries(expected)) {
    const job = ci[id];
    assert.ok(job, `ci.yml must define ${id}`);
    assert.match(String(job.if || ''), re, `${id} must be gated on its effective plan output`);
    const needs = Array.isArray(job.needs) ? job.needs : [job.needs];
    assert.ok(needs.includes('changes'), `${id} must need the changes job`);
  }
  // db-ops stays on its own classifier: it never runs on PRs by design.
  assert.match(String(ci['db-ops'].if || ''), /db_ops_relevant/, 'db-ops must keep its own DB-surface gate');
  assert.doesNotMatch(String(ci['db-ops'].if || ''), /eff_/, 'db-ops must not gate on eff_*');
  // D3 option A (owner-approved): docs-only PRs skip the test gate too;
  // a skipped required check counts as success (D2), and ci:full forces full.
  assert.match(
    String(ci['test'].if || ''),
    /eff_test != 'none'/,
    'test job must be gated on the effective test output',
  );
});

test('quarantined flakes skip only in the CI test job, never nightly/local', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.equal(ci['test'].env?.QUARANTINE, '1', 'test job must set QUARANTINE=1 (quarantine.txt applies in CI only)');
  assert.equal(
    ci['db-aggregate'].env?.QUARANTINE,
    '1',
    'db aggregate must set QUARANTINE=1 (count gate adjusts only for quarantined reports)',
  );
});

test('ci:full label forces a full run (CI-011)', () => {
  const job = collectWorkflowJobs()['ci.yml']['changes'];
  const runs = job.runs.join('\n');
  assert.match(runs, /classify_changes\.sh/, 'changes job must run the classifier script');
  const ciYaml = readFileSync(path.join(ROOT, '.github', 'workflows', 'ci.yml'), 'utf8');
  assert.match(ciYaml, /ci:full/, 'changes job must honor the ci:full label override');
});

test('docker-build runs on push and only for docker-relevant PRs', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  const cond = String(ci['docker-build'].if || '');
  assert.match(cond, /eff_docker == 'true'/, 'docker-build must gate on the effective docker output');
  const ciYaml = readFileSync(path.join(ROOT, '.github', 'workflows', 'ci.yml'), 'utf8');
  // The legacy classifiers still feed the planner: eff_docker reproduces
  // docs_only + push/docker_relevant/docker_definition exactly (shadow).
  assert.match(ciYaml, /DOCKER_RELEVANT: \$\{\{ steps\.classify\.outputs\.docker_relevant \}\}/);
  assert.match(ciYaml, /DOCKER_DEFINITION: \$\{\{ steps\.classify\.outputs\.docker_definition \}\}/);
  assert.match(ciYaml, /docker_relevant: \$\{\{ steps\.classify\.outputs\.docker_relevant \}\}/);
  assert.match(ciYaml, /docker_definition: \$\{\{ steps\.classify\.outputs\.docker_definition \}\}/);
});

test('push to main skips the PR-only DB gate (cost workstream)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  const expected = {
    test: /eff_test != 'none'/,
    'db-shards': /eff_db == 'full'/,
    'db-selected': /eff_db == 'selected'/,
    'db-aggregate': /eff_aggregate == 'true'/,
  };
  for (const [id, re] of Object.entries(expected)) {
    const cond = String(ci[id].if || '');
    assert.ok(
      cond.includes("github.event_name == 'pull_request'"),
      `${id} must run on pull_request only (push skips the DB gate)`,
    );
    assert.match(cond, re, `${id} must gate on its effective output (eff_* carries the docs-only skip)`);
  }
  assert.match(String(ci['coverage'].if || ''), /workflow_dispatch/, 'coverage must remain manually dispatchable');
  assert.match(
    String(ci['coverage'].if || ''),
    /eff_gateway_coverage == 'true'/,
    'coverage must gate on the effective gateway output',
  );
});

test('mutation anchors are validated before the weekly run', () => {
  const all = collectWorkflowJobs();
  assert.match(
    all['mutation.yml']['mutants'].runs.join('\n'),
    /money_path_mutants\.sh --check-anchors/,
    'mutation workflow must preflight anchors (fast fail instead of mid-run)',
  );
  assert.match(
    all['ci.yml']['lint'].runs.join('\n'),
    /money_path_mutants\.sh --check-anchors/,
    'lint must guard mutant anchors on every PR (~1s, no build/DB)',
  );
});

test('every upload-artifact step sets overwrite: true (CI-013)', () => {
  const script = `
import json, sys, glob, yaml
out = []
for f in sorted(glob.glob('GH/.github/workflows/*.yml'.replace('GH', sys.argv[1]))):
    try:
        with open(f) as fh:
            doc = yaml.safe_load(fh.read())
    except Exception:
        continue
    for job_id, spec in (doc.get('jobs') or {}).items():
        for step in (spec or {}).get('steps') or []:
            if isinstance(step, dict) and isinstance(step.get('uses'), str) and 'upload-artifact@' in step['uses']:
                with_ = step.get('with') or {}
                out.append([f, job_id, step.get('name'), bool(with_.get('overwrite'))])
print(json.dumps(out))
`;
  const stdout = execFileSync('python3', ['-c', script, ROOT], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: 60000,
  });
  const rows = JSON.parse(stdout);
  assert.ok(rows.length > 0, 'expected upload-artifact steps in workflows');
  for (const [file, job, name, overwrite] of rows) {
    assert.equal(overwrite, true, `${file} :: ${job} :: ${name} must set overwrite: true`);
  }
});

test('coverage is a real PR gateway gate; test skips its gateway phase', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  const coverageIf = String(ci['coverage'].if || '');
  assert.match(coverageIf, /github\.event_name == 'pull_request'/, 'coverage must run on pull requests');
  assert.match(
    coverageIf,
    /eff_gateway_coverage == 'true'/,
    'coverage must honor the effective gateway gate (docs-only skip included)',
  );
  assert.match(coverageIf, /workflow_dispatch/, 'coverage must remain manually dispatchable');
  assert.equal(ci['test'].env?.SKIP_GATEWAY, '1', 'test must not duplicate the coverage-owned gateway suite');
  assert.match(ci['coverage'].runs.join('\n'), /coverage\.sh --gateway-only/, 'coverage must run the gateway gate');
  assert.match(
    String(ci['coverage-pr'].if || ''),
    /github\.event_name == 'pull_request'/,
    'coverage-pr must run on pull requests',
  );
  assert.match(
    String(ci['coverage-pr'].if || ''),
    /eff_cobol_coverage == 'true'/,
    'coverage-pr must gate on the effective COBOL coverage output',
  );
  const aggNeeds = Array.isArray(ci['db-aggregate'].needs) ? ci['db-aggregate'].needs : [ci['db-aggregate'].needs];
  assert.ok(aggNeeds.includes('coverage'), 'db aggregate must wait for the gateway coverage gate');
});

test('test job runs the full gate or the selected ci-test gate (PR-03)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  const runs = ci['test'].runs.join('\n');
  assert.match(runs, /run_all\.sh full/, 'test job must keep the full gate (flag off)');
  assert.match(runs, /run_all\.sh ci-test/, 'test job must run the selected ci-test gate (flag on)');
  const ciYaml = readFileSync(path.join(ROOT, '.github', 'workflows', 'ci.yml'), 'utf8');
  assert.match(ciYaml, /eff_test == 'full'/, 'full step must gate on eff_test full');
  assert.match(ciYaml, /eff_test == 'selected'/, 'selected step must gate on eff_test selected');
  assert.match(ciYaml, /SELECT_CASE_FILES/, 'selected step must pass the table cases');
  assert.match(ciYaml, /SELECT_NODE_SUITE/, 'selected step must pass the node suite');
  assert.match(ciYaml, /SELECT_INTEGRATION_MODE/, 'selected step must pass the integration mode');
});

test('lint scopes docs vs full steps on eff_lint (PR-02)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  const lint = ci['lint'];
  assert.ok(lint, 'ci.yml must define a lint job');
  const lintNeeds = Array.isArray(lint.needs) ? lint.needs : [lint.needs];
  assert.ok(lintNeeds.includes('changes'), 'lint must need the changes job for the eff_lint scope');
  const runs = lint.runs.join('\n');
  assert.match(runs, /lint_docs\.sh/, 'lint must run the docs scope script');
  assert.match(runs, /tests\/run_all\.sh gates/, 'lint must still run the full gate fleet');
  const ciYaml = readFileSync(path.join(ROOT, '.github', 'workflows', 'ci.yml'), 'utf8');
  assert.match(ciYaml, /name: Install docs Python deps/, 'lint must install docs Python deps');
  assert.match(ciYaml, /name: Install full Python deps/, 'lint must install full Python deps');
  assert.match(ciYaml, /eff_lint == 'docs'/, 'docs steps must gate on eff_lint docs');
  assert.match(ciYaml, /eff_lint == 'full'/, 'full steps must gate on eff_lint full');
});

test('impact selection has a selected DB path and a full fallback', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.ok(ci['db-selected'], 'ci.yml must define the db-selected job');
  assert.match(String(ci['db-selected'].if || ''), /eff_db == 'selected'/);
  assert.match(String(ci['db-selected'].if || ''), /eff_db_suites != ''/);
  assert.match(ci['db-selected'].runs.join('\n'), /run_all\.sh db-selected/);
  assert.match(String(ci['db-shards'].if || ''), /eff_db == 'full'/);
  const aggNeeds = Array.isArray(ci['db-aggregate'].needs) ? ci['db-aggregate'].needs : [ci['db-aggregate'].needs];
  assert.ok(aggNeeds.includes('db-selected'), 'db aggregate must wait for the selected path');
  const ciYaml = readFileSync(path.join(ROOT, '.github', 'workflows', 'ci.yml'), 'utf8');
  assert.match(ciYaml, /eff_db_suites: \$\{\{ steps\.impact\.outputs\.eff_db_suites \}\}/);
});

test('db consumers wait for the snapshot producer (CI-008B ordering)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  for (const id of ['test', 'db-shards', 'db-selected', 'coverage', 'coverage-pr', 'db-ops']) {
    const job = ci[id];
    assert.ok(job, `ci.yml must define ${id}`);
    const needs = Array.isArray(job.needs) ? job.needs : [job.needs];
    assert.ok(needs.includes('db-snapshot'), `${id} must need db-snapshot (no silent fallback race)`);
  }
});

test('impact plan is computed in changes and audited advisory-only (PR-01 shadow)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  const ciYaml = readFileSync(path.join(ROOT, '.github', 'workflows', 'ci.yml'), 'utf8');
  const changes = ci['changes'];
  assert.ok(changes, 'ci.yml must define a changes job');
  for (const name of [
    'plan_mode',
    'plan_lint',
    'plan_build',
    'plan_test',
    'plan_db',
    'plan_db_suites',
    'plan_gateway_coverage',
    'plan_cobol_coverage',
    'plan_enforce',
    'plan_reason',
    'eff_lint',
    'eff_build',
    'eff_test',
    'eff_db',
    'eff_db_suites',
    'eff_gateway_coverage',
    'eff_cobol_coverage',
    'eff_aggregate',
    'eff_aggregate_mode',
    'eff_db_snapshot',
  ]) {
    assert.match(
      ciYaml,
      new RegExp(`${name}: \\$\\{\\{ steps\\.impact\\.outputs\\.${name} \\}\\}`),
      `changes must expose output ${name}`,
    );
  }
  assert.match(changes.runs.join('\n'), /impact-plan\.mjs/, 'changes must run the impact planner');
  assert.match(changes.runs.join('\n'), /--fallback-full/, 'changes must restore a full plan when the planner fails');
  assert.match(ciYaml, /name: impact-plan/, 'changes must publish the impact-plan artifact');

  const audit = ci['plan-audit'];
  assert.ok(audit, 'ci.yml must define a plan-audit job');
  assert.equal(audit.name, 'plan audit');
  assert.equal(audit.timeout, 5);
  assert.match(String(audit.if || ''), /plan_enforce != 'true'/, 'plan audit must stay advisory');
  assert.match(audit.runs.join('\n'), /impact-audit\.mjs/, 'plan audit must run the audit script');
  assert.match(ciYaml, /name: impact-audit/, 'plan audit must publish the impact-audit artifact');

  // PR-02 gates heavy jobs on eff_*: no legacy per-job gating may remain.
  for (const id of [
    'build',
    'test',
    'db-shards',
    'db-selected',
    'coverage',
    'coverage-pr',
    'db-aggregate',
    'db-snapshot',
    'docker-build',
    'schema-drift',
  ]) {
    const cond = String(ci[id].if || '');
    assert.doesNotMatch(cond, /docs_only/, `${id} must not gate on docs_only (use eff_*)`);
    assert.doesNotMatch(cond, /select_mode/, `${id} must not gate on select_mode (use eff_*)`);
    assert.doesNotMatch(cond, /select_db_suites/, `${id} must not gate on select_db_suites (use eff_*)`);
    assert.doesNotMatch(cond, /coverage_relevant/, `${id} must not gate on coverage_relevant (use eff_*)`);
    assert.doesNotMatch(cond, /docker_relevant/, `${id} must not gate on docker_relevant (use eff_*)`);
    assert.doesNotMatch(cond, /docker_definition/, `${id} must not gate on docker_definition (use eff_*)`);
  }
});
