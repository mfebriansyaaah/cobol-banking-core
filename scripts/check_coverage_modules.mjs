// Per-module COBOL coverage ratchet.
//
// The curated-total gate (30% floor + total ratchet in scripts/ci/coverage.sh)
// lets one module collapse while another rises. This gate pins every curated
// module to its own baseline: a drop of more than --tolerance percentage
// points in ANY module fails, even when the total still looks fine.
//
// Usage:
//   node scripts/check_coverage_modules.mjs --json coverage/cobol.json
//       [--baseline tests/coverage_module_baseline.txt]
//       [--tolerance 1.0] [--write]
//   --write updates the baseline from the JSON (review the diff; never
//   hand-edit, never lower to make CI green).
// Exit: 0 ok, 1 mismatch, 2 usage error.
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let jsonPath = null;
let baselinePath = path.resolve('tests/coverage_module_baseline.txt');
let tolerance = 1.0;
let write = false;
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--json') jsonPath = args[i + 1] ?? jsonPath, i += 1;
  else if (a === '--baseline') baselinePath = path.resolve(args[i + 1] ?? baselinePath), i += 1;
  else if (a === '--tolerance') tolerance = Number(args[i + 1] ?? tolerance), i += 1;
  else if (a === '--write') write = true;
  else if (a === '--help' || a === '-h') {
    console.log('usage: check_coverage_modules.mjs --json FILE [--baseline FILE] [--tolerance PP] [--write]');
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
const improved = order.filter((k) => actual.has(k) && actual.get(k) - baseline.get(k) > 0);
console.log(`OK: ${order.length} module(s) at or above baseline (tolerance ${tolerance}pp${improved.length ? `, ${improved.length} improved` : ''})`);
