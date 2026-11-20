// Convert a green merged run-all.json into the committed shard timing file.
//
// Usage:
//   gh run download <run-id> -n test-reports-merged -D /tmp/merged
//   node scripts/ci/shard_timings.mjs /tmp/merged/run-all.json
//
// Writes tests/shard_timings.json. The planner uses measured durations
// (LPT scheduling) instead of assertion counts; a missing file falls back to
// tests/baseline_counts.txt. Keep this file updated from a representative
// green PR run, not from a local developer machine.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const input = process.argv[2];
if (!input) {
  console.error('usage: node scripts/ci/shard_timings.mjs <run-all.json>');
  process.exit(2);
}

let run;
try {
  run = JSON.parse(readFileSync(input, 'utf8'));
} catch (e) {
  console.error(`FAIL: cannot read ${input}: ${e.message}`);
  process.exit(1);
}
const suites = (Array.isArray(run) ? run : run.suites || [])
  .filter((s) => s && typeof s.suite === 'string' && /_db_tests\.sh$/.test(s.suite))
  .filter((s) => Number.isFinite(Number(s.duration_ms)) && Number(s.duration_ms) > 0)
  .map((s) => ({ suite: s.suite, duration_ms: Number(s.duration_ms) }))
  .sort((a, b) => a.suite.localeCompare(b.suite));
if (!suites.length) {
  console.error(`FAIL: no positive DB suite durations in ${input}`);
  process.exit(1);
}

const out = {
  generatedAt: new Date().toISOString(),
  source: path.basename(input),
  suites,
};
const target = path.join(ROOT, 'tests', 'shard_timings.json');
writeFileSync(target, `${JSON.stringify(out, null, 2)}\n`);
console.log(`wrote ${path.relative(ROOT, target)} (${suites.length} suites)`);
