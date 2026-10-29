// Shard planner for the DB suite fleet (Fase 2.3).
//
// Assigns every tests/db/*_db_tests.sh suite to one of N shards with
// longest-processing-time scheduling: suites sorted by weight (assertion
// count from tests/baseline_counts.txt, median 13 for unlisted suites),
// each dealt to the currently least-loaded shard. Deterministic for the
// same inputs, so reruns are comparable.
//
// Usage: node scripts/shard_suites.mjs <shards> [root]
// Output lines: "<shard_index> <suite_path>" (suite_path relative to root).
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const shards = Math.max(1, parseInt(process.argv[2] || '1', 10) || 1);
const ROOT = path.resolve(process.argv[3] || '.');
const suitesDir = path.join(ROOT, 'tests', 'db');
const baselinePath = path.join(ROOT, 'tests', 'baseline_counts.txt');

const weights = new Map();
try {
  for (const raw of readFileSync(baselinePath, 'utf8').split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.lastIndexOf('=');
    if (eq < 0) continue;
    const key = line.slice(0, eq).trim();
    const n = parseInt(line.slice(eq + 1).trim(), 10);
    if (!Number.isFinite(n)) continue;
    const m = key.match(/^db_(.+)_tests$/);
    if (m) weights.set(`${m[1]}_db_tests.sh`, n);
  }
} catch {
  // No baseline: every suite gets the median weight below.
}

const MEDIAN_WEIGHT = 13;
const suites = readdirSync(suitesDir)
  .filter((f) => f.endsWith('_db_tests.sh'))
  .map((f) => ({ file: f, weight: weights.get(f) ?? MEDIAN_WEIGHT }))
  .sort((a, b) => b.weight - a.weight || (a.file < b.file ? -1 : 1));

const loads = new Array(Math.min(shards, suites.length)).fill(0);
const buckets = loads.map(() => []);
for (const s of suites) {
  let best = 0;
  for (let i = 1; i < loads.length; i += 1) {
    if (loads[i] < loads[best]) best = i;
  }
  buckets[best].push(s.file);
  loads[best] += s.weight;
}

buckets.forEach((files, idx) => {
  for (const f of files) console.log(`${idx} tests/db/${f}`);
});
