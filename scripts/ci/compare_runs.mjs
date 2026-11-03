// Compare two tests/run_all.sh --json reports for the nightly flake gate.
// Only result fields are compared (suite, status, pass, fail, total);
// durations and timestamps are timing noise, not flakes. Missing or extra
// suites count as inconsistent.
// Usage: node scripts/ci/compare_runs.mjs <run1.json> <run2.json>
import { readFileSync } from 'node:fs';

const [aPath, bPath] = process.argv.slice(2);
if (!aPath || !bPath) {
  console.error('usage: node scripts/ci/compare_runs.mjs <run1.json> <run2.json>');
  process.exit(2);
}

function load(p) {
  const d = JSON.parse(readFileSync(p, 'utf8'));
  const rows = Array.isArray(d) ? d : d.suites || [];
  const m = new Map();
  for (const r of rows) {
    if (!r || typeof r.suite !== 'string') continue;
    const key = `${r.suite}\t${r.shard ?? ''}`;
    if (m.has(key)) m.get(key).push(r);
    else m.set(key, [r]);
  }
  // A suite recorded twice (e.g. rerun in one invocation) is itself an
  // inconsistency worth flagging, not something to average away.
  return m;
}

let a;
let b;
try {
  a = load(aPath);
  b = load(bPath);
} catch (e) {
  console.error(`FAIL: cannot read reports: ${e.message}`);
  process.exit(2);
}

const fails = [];
const fields = ['status', 'pass', 'fail', 'total'];
for (const [key, ar] of [...a.entries()].sort()) {
  const br = b.get(key);
  if (!br) {
    fails.push(`missing in second run: ${key}`);
    continue;
  }
  if (ar.length !== br.length) {
    fails.push(`recorded ${ar.length}x vs ${br.length}x: ${key}`);
    continue;
  }
  for (let i = 0; i < ar.length; i += 1) {
    for (const f of fields) {
      if (ar[i][f] !== br[i][f]) {
        fails.push(`differs ${key}: ${f} ${ar[i][f]} vs ${br[i][f]}`);
      }
    }
  }
}
for (const key of [...b.keys()].sort()) {
  if (!a.has(key)) fails.push(`missing in first run: ${key}`);
}

if (!fails.length) {
  console.log(`OK: ${a.size} suite records consistent across both runs`);
  process.exit(0);
}
console.error(`FAIL: ${fails.length} inconsistency(ies) between runs (possible flake):`);
for (const f of fails.slice(0, 30)) console.error(`  ${f}`);
process.exit(1);
