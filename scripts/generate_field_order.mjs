// Field-order snapshot generator for the gateway<->COBOL contract (P0-4).
// The 6 positional `fields` of every route must reach the COBOL module in
// exactly this order; a swap compiles, runs, and returns another customer's
// data (see tests/probes p5b). The snapshot is an anti-drift ratchet: any
// added/removed/changed route or field order fails check_field_order.mjs
// until the snapshot is regenerated AND the diff is reviewed.
//
// Usage:
//   node scripts/generate_field_order.mjs [--check] [--write] [root]
//   --check  compare live routes against tests/contracts/route_field_order.json
//   --write  regenerate the snapshot (review the diff before committing)
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { collectRoutes } from './lib/route_fields.mjs';

const args = process.argv.slice(2);
let check = false;
let write = false;
let root = '.';
for (const a of args) {
  if (a === '--check') check = true;
  else if (a === '--write') write = true;
  else if (a === '--help' || a === '-h') {
    console.log('usage: generate_field_order.mjs [--check] [--write] [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else root = a;
}
const ROOT = path.resolve(root);
const SNAP = path.join(ROOT, 'tests', 'contracts', 'route_field_order.json');

const live = collectRoutes(ROOT);
const snapObj = {};
for (const [k, v] of [...live.entries()].sort(([a], [b]) => (a < b ? -1 : 1))) snapObj[k] = v;

if (write) {
  mkdirSync(path.dirname(SNAP), { recursive: true });
  writeFileSync(SNAP, `${JSON.stringify(snapObj, null, 2)}\n`);
  console.log(`wrote ${Object.keys(snapObj).length} route(s) to ${path.relative(ROOT, SNAP)}`);
  process.exit(0);
}

if (!existsSync(SNAP)) {
  console.error(`FAIL: missing snapshot ${SNAP}; generate it with --write and review the diff`);
  process.exit(1);
}

let recorded;
try {
  recorded = JSON.parse(readFileSync(SNAP, 'utf8'));
} catch (e) {
  console.error(`FAIL: cannot parse ${SNAP}: ${e.message}`);
  process.exit(1);
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
let failed = false;
const liveKeys = new Set(Object.keys(snapObj));
const recordedKeys = new Set(Object.keys(recorded));

for (const k of [...recordedKeys].filter((k) => !liveKeys.has(k)).sort()) {
  failed = true;
  console.error(`REMOVED route (stale snapshot entry): ${k}`);
}
for (const k of [...liveKeys].filter((k) => !recordedKeys.has(k)).sort()) {
  failed = true;
  console.error(`NEW route without snapshot entry: ${k} (action ${JSON.stringify(snapObj[k].action)})`);
}
for (const k of [...liveKeys].filter((k) => recordedKeys.has(k)).sort()) {
  if (!same(recorded[k], snapObj[k])) {
    failed = true;
    console.error(`FIELD DRIFT: ${k}`);
    console.error(`  snapshot: ${JSON.stringify(recorded[k])}`);
    console.error(`  live:     ${JSON.stringify(snapObj[k])}`);
  }
}

if (failed) {
  console.error('\nFAIL: route field-order drift. If intentional, regenerate with --write and review the diff.');
  process.exit(1);
}
console.log(`OK: ${liveKeys.size} route(s) match the field-order snapshot`);
