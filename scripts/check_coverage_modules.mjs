// Per-module COBOL coverage ratchet.
//
// The curated-total gate is a 30% floor only (scripts/ci/coverage.sh); the
// total cannot see one module collapsing while another rises, so this gate
// pins every curated module to its own baseline: a drop of more than
// --tolerance percentage points in ANY module fails, even when the total
// still looks fine. Shared copybook lines are measured separately as a
// `copybooks` union unit (see scripts/coverage/map_cobol.py), not here.
//
// Usage:
//   node scripts/check_coverage_modules.mjs --json coverage/cobol.json
//       [--baseline tests/coverage_module_baseline.txt]
//       [--tolerance 1.0] [--floor 70] [--linkage-graph manifest/linkage_graph.json] [--write]
//       [--allow-stale] treats stale floor-backlog entries (module reached
//       the floor but still listed) as warnings, not failures. CI passes
//       --allow-stale; the weekly report flags entries stale >7 days.
//   --write updates the baseline from the JSON (review the diff; never
//   hand-edit, never lower to make CI green).
// Exit: 0 ok, 1 mismatch, 2 usage error.
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let jsonPath = null;
let baselinePath = path.resolve('tests/coverage_module_baseline.txt');
let tolerance = 1.0;
let floor = 0;
let floorBacklogPath = path.resolve('tests/coverage_floor_backlog.txt');
let linkageGraphPath = path.resolve('manifest/linkage_graph.json');
let write = false;
let allowStale = false;
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--json') ((jsonPath = args[i + 1] ?? jsonPath), (i += 1));
  else if (a === '--baseline') ((baselinePath = path.resolve(args[i + 1] ?? baselinePath)), (i += 1));
  else if (a === '--tolerance') ((tolerance = Number(args[i + 1] ?? tolerance)), (i += 1));
  else if (a === '--floor') ((floor = Number(args[i + 1] ?? floor)), (i += 1));
  else if (a === '--floor-backlog') ((floorBacklogPath = path.resolve(args[i + 1] ?? floorBacklogPath)), (i += 1));
  else if (a === '--linkage-graph') ((linkageGraphPath = path.resolve(args[i + 1] ?? linkageGraphPath)), (i += 1));
  else if (a === '--allow-stale') allowStale = true;
  else if (a === '--write') write = true;
  else if (a === '--help' || a === '-h') {
    console.log(
      'usage: check_coverage_modules.mjs --json FILE [--baseline FILE] [--tolerance PP] [--floor N] [--linkage-graph FILE] [--allow-stale] [--write]',
    );
    process.exit(0);
  } else {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  }
}
if (!jsonPath) {
  console.error('FAIL: --json coverage/cobol.json is required');
  process.exit(2);
}
if (!Number.isFinite(tolerance) || tolerance < 0) {
  console.error('FAIL: --tolerance must be a non-negative number');
  process.exit(2);
}

const fail = (msg) => {
  console.error(`FAIL coverage modules: ${msg}`);
  process.exit(1);
};

if (!existsSync(jsonPath)) fail(`missing ${jsonPath} (run scripts/ci/coverage.sh first)`);
let report;
try {
  report = JSON.parse(readFileSync(jsonPath, 'utf8'));
} catch (e) {
  fail(`cannot parse ${jsonPath}: ${e.message}`);
}
if (!Array.isArray(report.modules)) fail(`${jsonPath} has no modules[] array`);

if (!existsSync(baselinePath)) fail(`missing ${baselinePath}`);
const raw = readFileSync(baselinePath, 'utf8').split('\n');
const baseline = new Map();
const order = [];
for (const line of raw) {
  const t = line.trim();
  if (!t || t.startsWith('#') || !t.includes(' ')) continue;
  const [mod, val] = t.split(/\s+/);
  const n = Number(val);
  if (!Number.isFinite(n)) fail(`non-numeric baseline value: ${line}`);
  baseline.set(mod, n);
  order.push(mod);
}

const actual = new Map(report.modules.map((m) => [m.module, Number(m.percent)]));

let failed = false;
const unlisted = [...actual.keys()].filter((k) => !baseline.has(k)).sort();
if (unlisted.length) {
  failed = true;
  console.error('MODULES WITH NO BASELINE ENTRY (drops would go unnoticed):');
  for (const k of unlisted) console.error(`  ${k} (actual ${actual.get(k)}%)`);
}
const missing = order.filter((k) => !actual.has(k));
if (missing.length) {
  failed = true;
  console.error('BASELINE MODULES WITH NO MEASUREMENT (removed from the curated set?):');
  for (const k of missing) console.error(`  ${k} (baseline ${baseline.get(k)}%)`);
}
const drifts = [];
for (const k of order) {
  if (!actual.has(k)) continue;
  const delta = actual.get(k) - baseline.get(k);
  if (delta < -tolerance) drifts.push({ mod: k, base: baseline.get(k), value: actual.get(k), delta });
}
if (drifts.length) {
  failed = true;
  console.error(`MODULES BELOW BASELINE (tolerance ${tolerance}pp):`);
  for (const d of drifts.sort((a, b) => a.delta - b.delta)) {
    console.error(`  ${d.mod}: baseline=${d.base}% actual=${d.value}% (delta ${d.delta.toFixed(2)}pp)`);
  }
}

if (write) {
  // New keys are added deliberately here (the diff is reviewed); the
  // non-write mode is what fails on unlisted modules. Missing keys are kept.
  const updates = new Map();
  for (const [k, v] of actual) {
    if (!baseline.has(k) || baseline.get(k) !== v) updates.set(k, v);
  }
  if (!updates.size) {
    console.log('module baseline already matches; nothing to write');
  } else {
    const out = [];
    const seen = new Set();
    for (const line of raw) {
      const t = line.trim();
      if (!t || t.startsWith('#') || !t.includes(' ')) {
        out.push(line);
        continue;
      }
      const mod = t.split(/\s+/)[0];
      seen.add(mod);
      out.push(updates.has(mod) ? `${mod} ${updates.get(mod)}` : line);
    }
    for (const [k, v] of updates) {
      if (!seen.has(k)) out.push(`${k} ${v}`);
    }
    writeFileSync(baselinePath, `${out.join('\n').replace(/\n+$/, '')}\n`);
    console.log(`wrote ${updates.size} module baseline value(s):`);
    for (const [k, v] of updates) console.log(`  ${k}: ${baseline.get(k) ?? '(new)'} -> ${v}`);
  }
  process.exit(0);
}

if (failed) {
  console.error(`\nFAIL: per-module coverage does not match ${baselinePath}`);
  process.exit(1);
}

// L3 floor (linkage-only): measured L3 modules must sit at or above
// --floor, unless explicitly recorded in the floor backlog (ratchet both
// ways: unlisted sub-floor modules fail, and backlogged modules that reach
// the floor must leave the backlog).
if (floor > 0) {
  let l3 = [];
  try {
    const graph = JSON.parse(readFileSync(linkageGraphPath, 'utf8'));
    l3 = (graph.modules || []).filter((m) => m.linkageLevel === 'L3').map((m) => m.module);
  } catch {
    console.error(`FAIL: cannot load ${linkageGraphPath} for floor check`);
    process.exit(1);
  }
  const backlogged = new Set();
  if (existsSync(floorBacklogPath)) {
    for (const line of readFileSync(floorBacklogPath, 'utf8').split('\n')) {
      const t = line.trim();
      if (!t || t.startsWith('#')) continue;
      backlogged.add(t.split(/\s+/)[0]);
    }
  }
  let floorFailed = false;
  const unmeasuredL3 = l3.filter((m) => !actual.has(m) && !backlogged.has(m));
  for (const m of unmeasuredL3) {
    console.error(`FLOOR VIOLATION: L3 ${m} is unmeasured; add it to the curated set or record it`);
    floorFailed = true;
  }
  for (const m of l3) {
    if (!actual.has(m)) continue; // unmeasured handled above
    const v = actual.get(m);
    if (v >= floor) {
      if (backlogged.has(m)) {
        if (allowStale) {
          console.error(`WARN: FLOOR-BACKLOG STALE: ${m} reached ${v}% (>= ${floor}%); remove it`);
        } else {
          console.error(`FLOOR-BACKLOG STALE: ${m} reached ${v}% (>= ${floor}%); remove it`);
          floorFailed = true;
        }
      }
    } else if (!backlogged.has(m)) {
      console.error(`FLOOR VIOLATION: L3 ${m} at ${v}% (< ${floor}%); add tests or record it`);
      floorFailed = true;
    }
  }
  for (const m of backlogged) {
    if (!l3.includes(m)) {
      console.error(`FLOOR-BACKLOG DEAD: ${m} is not an L3 module; remove it`);
      floorFailed = true;
    }
  }
  if (floorFailed) {
    console.error('\nFAIL: L3 floor check');
    process.exit(1);
  }
  console.log(`OK: L3 floor ${floor}% holds (${l3.filter((m) => actual.has(m)).length} measured)`);
}
const improved = order.filter((k) => actual.has(k) && actual.get(k) - baseline.get(k) > 0);
console.log(
  `OK: ${order.length} module(s) at or above baseline (tolerance ${tolerance}pp${improved.length ? `, ${improved.length} improved` : ''})`,
);
