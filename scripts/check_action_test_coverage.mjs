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
// Baseline entries carry metadata so exceptions stay owned and expire:
//   ACTION  owner=@handle  reason="why untested"  expires=YYYY-MM-DD  ticket=REF
// The gate fails on missing/placeholder metadata and on expired entries.
// Categories come from the `# --- N. ...` section headers in the file.
//
// Usage:
//   node scripts/check_action_test_coverage.mjs [--root DIR] [--write] [--json]
//   --write updates tests/action_test_coverage_baseline.txt (review the diff;
//   new actions land ungrouped at the end with placeholder metadata - fill it
//   in and move them under a category header with a documented reason).
//   --json prints {"total","covered","pct","baseline","uncovered":[...]} to
//   stdout; the exit code still reflects the gate (0 ok, 1 mismatch).
// Exit: 0 ok, 1 mismatch, 2 usage error.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
let write = false;
let json = false;
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--root') {
    root = args[i + 1] ?? root;
    i += 1;
  } else if (a === '--write') write = true;
  else if (a === '--json') json = true;
  else if (a === '--help' || a === '-h') {
    console.log('usage: check_action_test_coverage.mjs [--root DIR] [--write] [--json]');
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

const META_KEYS = ['owner', 'reason', 'expires', 'ticket'];
const PLACEHOLDER = '?';

function parseMeta(rest) {
  // Parses `key=value` pairs where values are "quoted strings" or bare tokens.
  const meta = {};
  const re = /(\w+)=("[^"]*"|\S+)/g;
  let m;
  while ((m = re.exec(rest)) !== null) {
    const [, k, v] = m;
    if (!META_KEYS.includes(k)) {
      console.error(`FAIL: unknown metadata key: ${k} (want one of ${META_KEYS.join(', ')})`);
      process.exit(2);
    }
    if (meta[k] !== undefined) {
      console.error(`FAIL: duplicate metadata key: ${k}`);
      process.exit(2);
    }
    meta[k] = v.startsWith('"') && v.endsWith('"') ? v.slice(1, -1) : v;
  }
  const leftover = rest.replace(/(\w+)=("[^"]*"|\S+)/g, '').trim();
  if (leftover) {
    console.error(`FAIL: malformed metadata segment: ${leftover}`);
    process.exit(2);
  }
  return meta;
}

function metaProblems(action, meta) {
  // Returns human-readable problems; empty means the metadata is complete.
  const problems = [];
  if (!meta.owner || meta.owner === PLACEHOLDER || !/^@\S+$/.test(meta.owner)) {
    problems.push('missing owner=@handle');
  }
  if (!meta.reason || meta.reason === PLACEHOLDER) {
    problems.push('missing reason="..."');
  }
  if (!meta.expires || meta.expires === PLACEHOLDER || !/^\d{4}-\d{2}-\d{2}$/.test(meta.expires)) {
    problems.push('missing expires=YYYY-MM-DD');
  }
  if (!meta.ticket || meta.ticket === PLACEHOLDER) {
    problems.push('missing ticket=REF');
  }
  return problems;
}

function loadBaseline() {
  if (!existsSync(baselinePath)) return { order: [], values: new Map(), meta: new Map(), raw: [] };
  const raw = readFileSync(baselinePath, 'utf8').split('\n');
  const order = [];
  const values = new Map();
  const meta = new Map(); // action -> {owner, reason, expires, ticket, category}
  let category = 'ungrouped';
  for (const line of raw) {
    const t = line.trim();
    if (!t) continue;
    if (t.startsWith('#')) {
      const hm = t.match(/^#\s*-+\s*\d+\.\s*(.+?)\s*$/);
      if (hm) category = hm[1];
      else if (/^#\s*-+\s*new entries\b/i.test(t)) category = 'new entries (uncategorized)';
      continue;
    }
    const key = t.split(/\s+/)[0];
    if (!/^[A-Z][A-Z0-9_]+$/.test(key)) {
      console.error(`FAIL: malformed baseline line: ${line}`);
      process.exit(2);
    }
    values.set(key, (values.get(key) ?? 0) + 1);
    if (!order.includes(key)) {
      order.push(key);
      meta.set(key, { ...parseMeta(t.slice(key.length)), category });
    }
  }
  const dupes = [...values.entries()].filter(([, n]) => n > 1).map(([k]) => k);
  if (dupes.length) {
    console.error(`FAIL: duplicate baseline entries: ${dupes.join(', ')}`);
    process.exit(2);
  }
  return { order, values, meta, raw };
}

const routes = routeActions();
const shell = shellCovered();
const { order: recorded, meta: recordedMeta, raw } = loadBaseline();
const today = new Date().toISOString().slice(0, 10);

let failed = false;
// New untested actions: in routes, never shell-executed, not recorded.
const unlisted = [...routes.keys()].filter((a) => !shell.has(a) && !recorded.includes(a)).sort();
// Stale entries: recorded but now shell-covered (test was added, entry left behind).
const stale = recorded.filter((a) => shell.has(a));
// Baseline entries for actions that no longer exist as routes (dead entries).
const dead = recorded.filter((a) => !routes.has(a));
// Expired or metadata-less entries: owned exceptions that lapsed or were
// never properly recorded. Placeholders (?, written by --write for new
// actions) fail until a human fills them in. Dead entries are already
// failures on their own; they are not double-reported here.
const live = recorded.filter((a) => !shell.has(a) && routes.has(a));
const expired = live.filter((a) => recordedMeta.get(a)?.expires && recordedMeta.get(a).expires < today);
const unowned = live.filter((a) => metaProblems(a, recordedMeta.get(a) ?? {}).length > 0);

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
  if (expired.length) {
    failed = true;
    console.error('BASELINE ENTRIES PAST THEIR EXPIRES DATE (renew or add the test):');
    for (const a of expired.sort()) {
      console.error(`  ${a}  (expired ${recordedMeta.get(a).expires})`);
    }
  }
  if (unowned.length) {
    failed = true;
    console.error('BASELINE ENTRIES WITHOUT OWNER/REASON/EXPIRY/TICKET (fill them in):');
    for (const a of unowned.sort().slice(0, 10)) {
      console.error(`  ${a}  (${metaProblems(a, recordedMeta.get(a) ?? {}).join('; ')})`);
    }
    if (unowned.length > 10) console.error(`  ... and ${unowned.length - 10} more`);
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
    if (want.has(key)) out.push(line);
    // else: stale or dead entry -> drop it (reported above when not writing).
  }
  const added = [...want].filter((k) => !seen.has(k)).sort();
  if (added.length) {
    out.push('# --- new entries (fill metadata + move under a category header) ---');
    for (const k of added) out.push(`${k}  owner=? reason=? expires=? ticket=?`);
  }
  writeFileSync(baselinePath, `${out.join('\n').replace(/\n+$/, '')}\n`);
  const removed = recorded.filter((k) => !want.has(k));
  console.log(`wrote ${baselinePath}: +${added.length} -${removed.length} (total ${want.size})`);
  if (added.length) console.log(`  added (categorize under a header + document the reason):\n    ${added.join(', ')}`);
  if (removed.length) console.log(`  removed (now covered or unrouted): ${removed.sort().join(', ')}`);
  console.log(
    '  note: new entries carry placeholder metadata; the gate fails until a human fills owner/reason/expires/ticket',
  );
  process.exit(0);
}

const covered = [...routes.keys()].filter((a) => shell.has(a)).length;
const pct = ((100 * covered) / routes.size).toFixed(1);
const summary = {
  total: routes.size,
  covered,
  pct: Number(pct),
  baseline: recorded.length,
  uncovered: [...routes.keys()]
    .filter((a) => !shell.has(a))
    .sort()
    .map((a) => ({
      action: a,
      files: [...(routes.get(a) ?? [])].sort(),
      category: recordedMeta.get(a)?.category ?? null,
      ...(recordedMeta.get(a) ?? {}),
    })),
};
if (json) {
  // Always print the machine-readable summary; the exit code still
  // reflects the gate so --json works for both triage and gating.
  console.log(JSON.stringify(summary, null, 2));
}

if (failed) {
  console.error(`\nFAIL: action test coverage does not match ${baselinePath}`);
  process.exit(1);
}
if (!json) {
  console.log(
    `OK: ${covered} of ${routes.size} route actions shell-covered (${pct}%); baseline holds ${recorded.length} untested`,
  );
}
