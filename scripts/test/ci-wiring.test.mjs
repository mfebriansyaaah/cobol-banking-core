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
  ['scripts/check_pr_size_policy.mjs', ['check_pr_size_policy']],
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

test('schema-drift is a separate job, parallel to db-snapshot', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.ok(ci['schema-drift'], 'ci.yml must define a schema-drift job');
  assert.equal(ci['schema-drift'].name, 'schema-drift');
  const runs = ci['schema-drift'].runs.join('\n');
  assert.match(runs, /check_schema_drift/, 'schema-drift must run the drift check');
  const needs = Array.isArray(ci['schema-drift'].needs) ? ci['schema-drift'].needs : [ci['schema-drift'].needs];
  assert.ok(needs.includes('changes'), 'schema-drift must honor the docs-only gate');
  assert.ok(
    !needs.includes('db-snapshot'),
    'schema-drift must not depend on db-snapshot: a stale snapshot must not block consumers',
  );
  assert.doesNotMatch(
    ci['db-snapshot'].runs.join('\n'),
    /check_schema_drift/,
    'db-snapshot must stay a pure producer (no drift check before the artifact upload)',
  );
  // schema-drift is not a required check by name; the required db aggregate
  // job must surface its failure so a stale snapshot still blocks merges.
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
  assert.match(
    String(ci['db-ops'].if),
    /github\.event_name != 'pull_request'/,
    'db-ops must be excluded from pull_request',
  );
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
  const ciTestRuns = all['ci.yml']['test'].runs.join('\n');
  assert.doesNotMatch(ciTestRuns, /bench\.sh/, 'PR test job must not run the benchmark');
  const idx = (needle) => nightlyJob.runs.findIndex((s) => s.includes(needle));
  assert.ok(idx('coverage.sh') >= 0 && idx('bench.sh') >= 0 && idx('load_gateway.sh') >= 0);
  assert.ok(idx('coverage.sh') < idx('bench.sh'), 'benchmark must run after gateway coverage');
  assert.ok(idx('bench.sh') < idx('load_gateway.sh'), 'benchmark must run before the load test');
});

test('docs-only PRs skip heavy jobs including the test gate (CI-011 option A)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.ok(ci['changes'], 'ci.yml must define a changes job');
  for (const id of ['db-shards', 'coverage-pr', 'db-aggregate', 'db-ops', 'test', 'db-snapshot']) {
    const job = ci[id];
    assert.ok(job, `ci.yml must define ${id}`);
    assert.match(
      String(job.if || ''),
      /needs\.changes\.outputs\.docs_only/,
      `${id} must be gated on the changes job output`,
    );
    const needs = Array.isArray(job.needs) ? job.needs : [job.needs];
    assert.ok(needs.includes('changes'), `${id} must need the changes job`);
  }
  // D3 option A (owner-approved): docs-only PRs skip the test gate too;
  // a skipped required check counts as success (D2), and ci:full forces full.
  assert.match(
    String(ci['test'].if || ''),
    /needs\.changes\.outputs\.docs_only/,
    'test job must be gated on the changes job output',
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
  const runs = collectWorkflowJobs()['ci.yml']['changes'].runs.join('\n');
  assert.match(runs, /ci:full/, 'changes job must honor the ci:full label override');
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

test('gateway coverage job is skipped on PRs; coverage-pr owns PR coverage (CI-009)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.match(
    String(ci['coverage'].if || ''),
    /github\.event_name != 'pull_request'/,
    'coverage job must be skipped on pull requests',
  );
  assert.match(
    String(ci['coverage-pr'].if || ''),
    /github\.event_name == 'pull_request'/,
    'coverage-pr must run on pull requests',
  );
});

test('db consumers wait for the snapshot producer (CI-008B ordering)', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  for (const id of ['test', 'db-shards', 'coverage', 'coverage-pr', 'db-ops']) {
    const job = ci[id];
    assert.ok(job, `ci.yml must define ${id}`);
    const needs = Array.isArray(job.needs) ? job.needs : [job.needs];
    assert.ok(needs.includes('db-snapshot'), `${id} must need db-snapshot (no silent fallback race)`);
  }
});
