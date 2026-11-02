// DB suite inventory guard.
//
// tests/run_all.sh db runs every tests/db/*_db_tests.sh it can find. That fixes
// the old hand-maintained list, but it also means deleting or renaming a suite
// silently shrinks the run while still printing GREEN — the denominator moves.
//
// tests/baseline_counts.txt already records the expected suite inventory (and
// per-suite assertion counts). This gate makes that file load-bearing: every
// db_<name>_tests entry must have a suite file, and every suite file must have
// an entry. Removing a suite is now a deliberate edit to the inventory, not a
// quiet loss of coverage.
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const baselinePath = path.join(ROOT, 'tests', 'baseline_counts.txt');
const suitesDir = path.join(ROOT, 'tests', 'db');

if (!existsSync(baselinePath)) {
  console.error(`FAIL: missing ${baselinePath}`);
  process.exit(1);
}

const entries = readFileSync(baselinePath, 'utf8')
  .split('\n')
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith('#'))
  .map((l) => l.split('=')[0].trim());

// Non-DB-suite counters that legitimately live in the same file.
const NOT_A_SUITE = new Set(['cobol_table_tests', 'gateway_tests']);

function suiteFileFor(key) {
  if (key === 'db_schema_tests') return 'schema_tests.sh';
  const m = key.match(/^db_(.+)_tests$/);
  if (!m) return null;
  return `${m[1]}_db_tests.sh`;
}

const expected = new Map();
const unknownKeys = [];
for (const key of entries) {
  if (NOT_A_SUITE.has(key)) continue;
  const file = suiteFileFor(key);
  if (!file) {
    unknownKeys.push(key);
    continue;
  }
  expected.set(file, key);
}

const actual = readdirSync(suitesDir)
  .filter((f) => f.endsWith('.sh'))
  .sort();

const missing = [...expected.keys()].filter((f) => !existsSync(path.join(suitesDir, f))).sort();
const unlisted = actual.filter((f) => !expected.has(f));

let failed = false;
if (unknownKeys.length) {
  failed = true;
  console.error('BASELINE KEYS THAT DO NOT MAP TO A SUITE:');
  for (const k of unknownKeys) console.error(`  ${k}`);
}
if (missing.length) {
  failed = true;
  console.error('SUITES RECORDED IN baseline_counts.txt BUT MISSING ON DISK:');
  for (const f of missing) console.error(`  tests/db/${f}  (${expected.get(f)})`);
  console.error('  Restore the suite, or remove its line if the removal is intentional.');
}
if (unlisted.length) {
  failed = true;
  console.error('SUITE FILES WITH NO baseline_counts.txt ENTRY (coverage would grow untracked):');
  for (const f of unlisted) console.error(`  tests/db/${f}`);
  console.error('  Add a line so the inventory keeps matching what runs.');
}
if (failed) {
  console.error(`\ninventory: ${baselinePath}`);
  process.exit(1);
}

console.log(`OK: ${actual.length} DB suite(s) match baseline_counts.txt`);
