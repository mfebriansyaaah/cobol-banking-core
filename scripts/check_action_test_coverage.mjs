// Action test-coverage gate: every gateway action must be executed by at
// least one shell-level test (DB suite, integration flow, or table case),
// or be recorded in the ratchet baseline.
//
// Rationale: tests/db suites call the COBOL binary directly, and table cases
// exercise validation paths. An action that no suite invokes can break
// without any test noticing — 502 of 507 *_UPDATE actions were in exactly
// that state (template suites never call UPDATE), plus route files whose
// action sets are richer than what their suites exercise.
//
// What counts as covered (all literal, no dynamic calls):
//   tests/db/*.sh, tests/integration/*.sh : run_cobol "ACTION|..."
//   tests/cobol/cases/*.cases             : name@@expected@@ACTION|...
// Gateway HTTP tests are NOT counted: reaching a route is not executing its
// COBOL action (see route-reachability vs field-order in docs/TESTING.md).
//
// Usage:
//   node scripts/check_action_test_coverage.mjs [--root DIR] [--write]
//   --write updates tests/action_test_coverage_baseline.txt (review the diff;
//   new actions land ungrouped at the end - move them under a category header
//   and document the reason).
// Exit: 0 ok, 1 mismatch, 2 usage error.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
let write = false;
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--root') {
    root = args[i + 1] ?? root;
    i += 1;
  } else if (a === '--write') write = true;
  else if (a === '--help' || a === '-h') {
    console.log('usage: check_action_test_coverage.mjs [--root DIR] [--write]');
    process.exit(0);
  } else if (!a.startsWith('--')) root = a;
  else {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  }
}
root = path.resolve(root);

const baselinePath = path.join(root, 'tests', 'action_test_coverage_baseline.txt');

// ---- route actions (gateway surface) ----
function routeActions() {
  const found = new Map(); // action -> Set(files)
  const add = (file, src) => {
    for (const m of src.matchAll(/action:\s*'([A-Z0-9_]+)'/g)) {
      if (!found.has(m[1])) found.set(m[1], new Set());
      found.get(m[1]).add(file);
    }
  };
  const routesDir = path.join(root, 'middleware', 'src', 'routes');
  for (const f of readdirSync(routesDir).filter((x) => x.endsWith('.js') && x !== 'index.js')) {
    add(f, readFileSync(path.join(routesDir, f), 'utf8'));
  }
  add('app.js', readFileSync(path.join(root, 'middleware', 'src', 'app.js'), 'utf8'));
  return found;
}

// ---- shell-executed actions (literal invocations only) ----
function shellCovered() {
  const covered = new Map(); // action -> Set(files)
  const add = (action, file) => {
    if (!/^[A-Z][A-Z0-9_]+$/.test(action)) return;
    if (!covered.has(action)) covered.set(action, new Set());
    covered.get(action).add(file);
  };
  const shDirs = [path.join(root, 'tests', 'db'), path.join(root, 'tests', 'integration')];
  for (const dir of shDirs) {
    if (!existsSync(dir)) continue;
    for (const f of readdirSync(dir).filter((x) => x.endsWith('.sh'))) {
      const src = readFileSync(path.join(dir, f), 'utf8');
      for (const m of src.matchAll(/run_cobol\s+"([A-Z][A-Z0-9_]+)/g)) add(m[1], `tests/${path.basename(dir)}/${f}`);
    }
  }
  const casesDir = path.join(root, 'tests', 'cobol', 'cases');
  if (existsSync(casesDir)) {
    for (const f of readdirSync(casesDir).filter((x) => x.endsWith('.cases'))) {
      for (const line of readFileSync(path.join(casesDir, f), 'utf8').split('\n')) {
        const t = line.trim();
        if (!t || t.startsWith('#') || !t.includes('@@')) continue;
        const parts = t.split('@@');
        if (parts.length < 3) continue;
        add(parts[2].split('|')[0].trim(), `tests/cobol/cases/${f}`);
      }
    }
  }
  return covered;
}

function loadBaseline() {
  if (!existsSync(baselinePath)) return { order: [], values: new Map(), raw: [] };
  const raw = readFileSync(baselinePath, 'utf8').split('\n');
  const order = [];
  const values = new Map();
  for (const line of raw) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const key = t.split(/\s+/)[0];
    if (!/^[A-Z][A-Z0-9_]+$/.test(key)) {
      console.error(`FAIL: malformed baseline line: ${line}`);
      process.exit(2);
    }
    values.set(key, (values.get(key) ?? 0) + 1);
    if (!order.includes(key)) order.push(key);
  }
  const dupes = [...values.entries()].filter(([, n]) => n > 1).map(([k]) => k);
  if (dupes.length) {
    console.error(`FAIL: duplicate baseline entries: ${dupes.join(', ')}`);
    process.exit(2);
  }
  return { order, values, raw };
}

const routes = routeActions();
const shell = shellCovered();
const { order: recorded, raw } = loadBaseline();

let failed = false;
// New untested actions: in routes, never shell-executed, not recorded.
const unlisted = [...routes.keys()].filter((a) => !shell.has(a) && !recorded.includes(a)).sort();
// Stale entries: recorded but now shell-covered (test was added, entry left behind).
const stale = recorded.filter((a) => shell.has(a));
// Baseline entries for actions that no longer exist as routes (dead entries).
const dead = recorded.filter((a) => !routes.has(a));

if (!write) {
  if (unlisted.length) {
    failed = true;
    console.error('ACTIONS WITHOUT ANY SHELL TEST (add a test, or record with --write + reason):');
    for (const a of unlisted.slice(0, 30)) {
      console.error(`  ${a}  (route files: ${[...routes.get(a)].join(', ')})`);
    }
    if (unlisted.length > 30) console.error(`  ... and ${unlisted.length - 30} more`);
  }
  if (stale.length) {
    failed = true;
    console.error('BASELINE ENTRIES THAT ARE NOW COVERED (remove them):');
    for (const a of stale.sort()) {
      console.error(`  ${a}  (covered by: ${[...shell.get(a)].join(', ')})`);
    }
  }
  if (dead.length) {
    failed = true;
    console.error('BASELINE ENTRIES WITH NO ROUTE (action removed or renamed?):');
    for (const a of dead.sort()) console.error(`  ${a}`);
  }
}

if (write) {
  // Rewrite: preserve comments/blanks/structure, ensure exactly the uncovered set is listed.
  const want = new Set([...recorded.filter((a) => !shell.has(a) && routes.has(a)), ...unlisted]);
  const out = [];
  const seen = new Set();
  for (const line of raw) {
    const t = line.trim();
    if (!t || t.startsWith('#')) {
      out.push(line);
      continue;
    }
    const key = t.split(/\s+/)[0];
    if (seen.has(key)) continue;
    seen.add(key);
    if (want.has(key)) out.push(key);
    // else: stale or dead entry -> drop it (reported above when not writing).
  }
  for (const k of [...want].filter((k) => !seen.has(k)).sort()) out.push(k);
  writeFileSync(baselinePath, `${out.join('\n').replace(/\n+$/, '')}\n`);
  const added = [...want].filter((k) => !recorded.includes(k));
  const removed = recorded.filter((k) => !want.has(k));
  console.log(`wrote ${baselinePath}: +${added.length} -${removed.length} (total ${want.size})`);
  if (added.length)
    console.log(`  added (categorize under a header + document the reason):\n    ${added.sort().join(', ')}`);
  if (removed.length) console.log(`  removed (now covered or unrouted): ${removed.sort().join(', ')}`);
  process.exit(0);
}

if (failed) {
  console.error(`\nFAIL: action test coverage does not match ${baselinePath}`);
  process.exit(1);
}
const covered = [...routes.keys()].filter((a) => shell.has(a)).length;
const pct = ((100 * covered) / routes.size).toFixed(1);
console.log(
  `OK: ${covered} of ${routes.size} route actions shell-covered (${pct}%); baseline holds ${recorded.length} untested`,
);
