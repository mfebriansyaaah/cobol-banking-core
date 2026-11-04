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
  return entries
    .filter(([_, needles]) => !needles.some((n) => runSteps.some((s) => s.includes(n))))
    .map(([entry]) => entry);
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
