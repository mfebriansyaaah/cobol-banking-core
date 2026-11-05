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
  ['tests/perf/bench.sh', ['bench.sh']],
  ['tests/perf/load_gateway.sh', ['load_gateway.sh']],
  ['tests/gateway/endpoint_smoke.sh', ['endpoint_smoke.sh', 'run_all.sh full']],
  ['scripts/test/*.test.mjs', ['test:scripts', 'scripts/test/*.test.mjs']],
  ['scripts/ci/coverage.sh', ['coverage.sh']],
  ['scripts/check_test_counts.mjs', ['check_test_counts']],
  ['scripts/check_docs.mjs', ['check_docs']],
  ['scripts/check_schema_drift.sh', ['check_schema_drift']],
  ['scripts/check_warnings.sh', ['check_warnings']],
  ['scripts/ci/migration_rollback_drill.sh', ['migration_rollback_drill']],
  ['scripts/ci/backup_restore_drill.sh', ['backup_restore_drill']],
  // Local-only by design (schema snapshot helper; CI covers the same ground
  // through the rollback/backup drills + drift check).
  ['scripts/ci/restore_drill.sh', ['LOCAL-ONLY']],
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
const DRILL_NEEDLES = ['migration_rollback_drill', 'backup_restore_drill', 'check_schema_drift'];

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

test('db-ops job runs rollback, backup, and drift checks', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.ok(ci['db-ops'], 'ci.yml must define a db-ops job');
  assert.equal(ci['db-ops'].name, 'db-ops');
  assert.equal(ci['db-ops'].timeout, 20);
  const runs = ci['db-ops'].runs.join('\n');
  for (const needle of DRILL_NEEDLES) {
    assert.match(runs, new RegExp(needle), `db-ops must run ${needle}`);
  }
});

test('db-ops runs on push main and dispatch, never on PRs', () => {
  const ci = collectWorkflowJobs()['ci.yml'];
  assert.ok(ci['db-ops'], 'ci.yml must define a db-ops job');
  assert.equal(ci['db-ops'].needs, 'build');
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
