// Shard planner for the DB suite fleet (Fase 2.3).
//
// Assigns every tests/db/*_db_tests.sh suite to one of N shards with
// longest-processing-time scheduling: suites sorted by weight (measured
// durations from --timings artifacts/run-all.json when given, else assertion
// count from tests/baseline_counts.txt, median fallback for unlisted suites),
// each dealt to the currently least-loaded shard. Deterministic for the
// same inputs, so reruns are comparable.
//
// Usage: node scripts/shard_suites.mjs <shards> [root] [--timings run-all.json]
// Output lines: "<shard_index> <suite_path>" (suite_path relative to root).
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const argv = process.argv.slice(2);
const shards = Math.max(1, parseInt(argv[0] || '1', 10) || 1);
let ROOT = '.';
let timingsPath = null;
for (let i = 1; i < argv.length; i += 1) {
  const a = argv[i];
  if (a === '--timings') {
    timingsPath = argv[i + 1];
    i += 1;
  } else if (!a.startsWith('--') && ROOT === '.') {
    ROOT = a;
  } else if (a.startsWith('--')) {
    console.error(`unknown flag: ${a} (usage: node scripts/shard_suites.mjs <shards> [root] [--timings run-all.json])`);
    process.exit(2);
  } else {
    console.error(
      'unexpected extra positional argument (usage: node scripts/shard_suites.mjs <shards> [root] [--timings run-all.json])',
    );
    process.exit(2);
  }
}
ROOT = path.resolve(ROOT);
if (timingsPath === undefined) {
  console.error('usage: node scripts/shard_suites.mjs <shards> [root] [--timings run-all.json]');
  process.exit(2);
}
const suitesDir = path.join(ROOT, 'tests', 'db');
const baselinePath = path.join(ROOT, 'tests', 'baseline_counts.txt');

// Measured durations (ms) keyed by suite file name. Missing or non-positive
// entries fall back to the median of the measured ones, keeping one unit.
const measured = new Map();
let timingsNote = '';
if (timingsPath) {
  try {
    const run = JSON.parse(readFileSync(timingsPath, 'utf8'));
    const rows = Array.isArray(run) ? run : run.suites || [];
    for (const r of rows) {
      if (!r || typeof r.suite !== 'string') continue;
      const ms = Number(r.duration_ms);
      if (!Number.isFinite(ms) || ms <= 0) continue;
      const file = path.basename(String(r.suite));
      measured.set(file, Math.max(measured.get(file) || 0, ms));
    }
    if (!measured.size) timingsNote = `no usable durations in ${timingsPath}; using baseline weights`;
  } catch {
    // Unreadable timings: fall through to baseline weights below.
    timingsNote = `cannot read ${timingsPath}; using baseline weights`;
  }
  if (timingsNote) console.error(`note: ${timingsNote}`);
}
let medianMs = 0;
if (measured.size) {
  const sorted = [...measured.values()].sort((a, b) => a - b);
  medianMs = sorted[Math.floor(sorted.length / 2)];
}

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
  .map((f) => ({
    file: f,
    weight: measured.size ? (measured.get(f) ?? medianMs) : (weights.get(f) ?? MEDIAN_WEIGHT),
  }))
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
