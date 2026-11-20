// Core linkage gate (PR-009, linkage-only): every change must keep its core business
// link proven, or be recorded in the ratchet baseline.
//
// Fails on:
//   - missing/invalid manifest/linkage.json,
//   - manifest/linkage_graph.json out of sync (run build_linkage_graph.mjs --write),
//   - unlisted L0/L1 modules (new code without a test-backed core link),
//   - stale entries (baseline module now L2/L3: link proven, entry left behind),
//   - dead entries (baseline module file removed),
//   - unresolvable route files (no dispatch prefix and no matching module).
//
// Usage: node scripts/check_linkage.mjs [--root DIR]
// Exit: 0 ok, 1 mismatch, 2 usage error.
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { buildGraph } from './build_linkage_graph.mjs';

const args = process.argv.slice(2);
let root = '.';
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--root') {
    root = args[i + 1] ?? root;
    i += 1;
  } else if (a === '--help' || a === '-h') {
    console.log('usage: check_linkage.mjs [--root DIR]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
root = path.resolve(root);

let failed = false;
const fail = (msg) => {
  console.error(`FAIL: ${msg}`);
  failed = true;
};

const linkagePath = path.join(root, 'manifest', 'linkage.json');
if (!existsSync(linkagePath)) {
  console.error('FAIL: manifest/linkage.json missing');
  process.exit(1);
}
const linkage = JSON.parse(readFileSync(linkagePath, 'utf8'));
for (const key of ['coreModules', 'businessTables', 'moneyTables', 'moneyActions']) {
  if (!Array.isArray(linkage[key]) || linkage[key].length === 0)
    fail(`manifest/linkage.json: "${key}" must be a non-empty array`);
}

const linksPath = path.join(root, 'manifest', 'linkage_graph.json');
if (!existsSync(linksPath)) {
  console.error('FAIL: manifest/linkage_graph.json missing (run scripts/build_linkage_graph.mjs --write)');
  process.exit(1);
}
const recorded = JSON.parse(readFileSync(linksPath, 'utf8'));
const graph = buildGraph(root);

const strip = (modules) =>
  JSON.stringify(
    modules.map((m) => ({
      module: m.module,
      source: m.source,
      linkageLevel: m.linkageLevel,
      businessTables: m.businessTables,
      coreCalls: m.coreCalls,
      coreActions: m.coreActions,
      hasTests: m.hasTests,
      testEvidence: m.testEvidence,
      routeFiles: m.routeFiles,
      reason: m.reason,
    })),
  );
if (strip(recorded.modules || []) !== strip(graph.modules)) {
  fail('manifest/linkage_graph.json is out of sync (run scripts/build_linkage_graph.mjs --write and review the diff)');
}

const baselinePath = path.join(root, 'tests', 'linkage_baseline.txt');
const recordedLevels = new Map();
if (existsSync(baselinePath)) {
  for (const line of readFileSync(baselinePath, 'utf8').split('\n')) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const [module, level] = t.split(/\s+/);
    if (!module || (level !== 'L0' && level !== 'L1')) {
      console.error(`FAIL: malformed baseline line: ${line}`);
      process.exit(2);
    }
    if (recordedLevels.has(module)) {
      console.error(`FAIL: duplicate baseline entries: ${module}`);
      process.exit(2);
    }
    recordedLevels.set(module, level);
  }
} else {
  fail('tests/linkage_baseline.txt missing (run scripts/build_linkage_graph.mjs --write-baseline once)');
}

const current = new Map(graph.modules.map((m) => [m.module, m.linkageLevel]));
const unlisted = graph.modules.filter(
  (m) => (m.linkageLevel === 'L0' || m.linkageLevel === 'L1') && !recordedLevels.has(m.module),
);
const stale = [...recordedLevels.entries()].filter(
  ([module]) => current.has(module) && current.get(module) !== 'L0' && current.get(module) !== 'L1',
);
const dead = [...recordedLevels.keys()].filter((module) => !current.has(module));

if (unlisted.length) {
  failed = true;
  console.error(
    'NEW L0/L1 MODULES WITHOUT A PROVEN CORE LINK (link it to core, or record with --write-baseline + reason):',
  );
  for (const m of unlisted.slice(0, 30)) console.error(`  ${m.module}  (${m.linkageLevel}: ${m.reason})`);
  if (unlisted.length > 30) console.error(`  ... and ${unlisted.length - 30} more`);
}
if (stale.length) {
  failed = true;
  console.error('BASELINE ENTRIES THAT ARE NOW LINKED (remove them):');
  for (const [module] of stale.sort()) console.error(`  ${module}  (now ${current.get(module)})`);
}
if (dead.length) {
  failed = true;
  console.error('BASELINE ENTRIES WITH NO MODULE (module removed or renamed?):');
  for (const module of dead.sort()) console.error(`  ${module}`);
}
if (graph.unresolvedRoutes.length) {
  failed = true;
  console.error('ROUTE FILES WITH NO RESOLVABLE COBOL MODULE:');
  for (const f of graph.unresolvedRoutes) console.error(`  ${f}`);
}

if (failed) {
  console.error('\nFAIL: Core linkage does not match tests/linkage_baseline.txt');
  process.exit(1);
}
const { summary } = graph;
console.log(
  `OK: linkage in sync (L3 ${summary.L3}, L2 ${summary.L2}, L1 ${summary.L1}, L0 ${summary.L0}, UTILITY ${summary.UTILITY}); baseline holds ${recordedLevels.size} L0/L1`,
);
