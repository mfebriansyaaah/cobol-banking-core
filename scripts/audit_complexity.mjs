// Reproducible complexity audit (PR-001).
//
// Single source for the headline complexity numbers quoted in the master
// plan. All parsing is textual: COBOL sources, route files, migrations, and
// shell tests are read as text, never imported as code (importing the
// gateway would execute it). Regexes intentionally match the existing
// tooling:
//   - route actions: /action:\s*'([A-Z0-9_]+)'/  (docs_stats.mjs,
//     check_action_test_coverage.mjs, check_manifest.mjs)
//   - shell coverage: /run_cobol\s+"([A-Z][A-Z0-9_]+)/ + .cases @@ACTION|
//     (check_action_test_coverage.mjs)
//   - dispatch: parseDispatchTable() in scripts/lib/dispatch_table.mjs
//   - routes: collectRoutes() in scripts/lib/route_fields.mjs
//
// Usage:
//   node scripts/audit_complexity.mjs --json [--root DIR]
//   node scripts/audit_complexity.mjs --markdown [--root DIR]
//   node scripts/audit_complexity.mjs --write [--root DIR]
//   --write refreshes docs/COMPLEXITY_BASELINE.md (timestamp + commit).
// Exit: 0 ok, 2 usage error.
import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { collectRoutes } from './lib/route_fields.mjs';
import { parseDispatchTable, loadDispatchSource } from './lib/dispatch_table.mjs';

const args = process.argv.slice(2);
let root = '.';
let mode = 'json';
let write = false;
let check = false;
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--json') mode = 'json';
  else if (a === '--markdown') mode = 'markdown';
  else if (a === '--write') write = true;
  else if (a === '--check') check = true;
  else if (a === '--root') {
    root = args[i + 1] ?? root;
    i += 1;
  } else if (a === '--help' || a === '-h') {
    console.log('usage: audit_complexity.mjs [--json|--markdown] [--write|--check] [--root DIR]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
root = path.resolve(root);

const countLines = (file) => {
  const text = readFileSync(file, 'utf8');
  return text.split('\n').length - (text.endsWith('\n') ? 1 : 0);
};

const list = (dir, suffix) =>
  existsSync(dir)
    ? readdirSync(dir)
        .filter((f) => f.endsWith(suffix))
        .sort()
    : [];

// Canonical 9-action template shape (suffix set). Matches the 492 modules
// generated from cost_center_core.cob via scripts/generate_module.py.
const CANONICAL_9 = ['AUDIT', 'CALC', 'CREATE', 'DELETE', 'GET', 'LIST', 'SUMMARY', 'UPDATE', 'VALIDATE'];

function cobolActions(source) {
  const out = [];
  for (const m of source.matchAll(/WHEN LS-CMD-ACTION\(1:\d+\) = "([A-Z0-9_]+)"/g)) {
    out.push(m[1]);
  }
  return out;
}

function actionSuffixes(actions) {
  const std = new Set([...CANONICAL_9, 'ALLO', 'CLOSE']);
  const suffixes = new Set();
  for (const a of actions) {
    const suffix = a.split('_').pop();
    if (std.has(suffix)) suffixes.add(suffix);
  }
  return [...suffixes].sort();
}

function collectCobol(rootDir) {
  const cobolDir = path.join(rootDir, 'cobol', 'src');
  const files = list(cobolDir, '.cob');
  let loc = 0;
  let exact669 = 0;
  let canonical9 = 0;
  const lineCounts = [];
  for (const f of files) {
    const full = path.join(cobolDir, f);
    const lines = countLines(full);
    loc += lines;
    lineCounts.push(lines);
    if (lines === 669) exact669 += 1;
    if (f === 'main_logic.cob') continue;
    const src = readFileSync(full, 'utf8');
    const suffixes = actionSuffixes(cobolActions(src));
    if (JSON.stringify(suffixes) === JSON.stringify(CANONICAL_9)) canonical9 += 1;
  }
  return {
    files: files.length,
    modules: files.filter((f) => f !== 'main_logic.cob').length,
    loc,
    exact669,
    canonical9,
  };
}

function collectGateway(rootDir) {
  const routes = collectRoutes(rootDir);
  let mutating = 0;
  let total = 0;
  for (const [key, entry] of routes) {
    const entries = Array.isArray(entry) ? entry : [entry];
    const method = key.split('::')[1]?.trim().split(' ')[0] ?? '';
    total += entries.length;
    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method.toUpperCase())) mutating += entries.length;
  }
  const routeFiles = list(path.join(rootDir, 'middleware', 'src', 'routes'), '.js').filter(
    (f) => f !== 'index.js',
  ).length;
  // Express layers: 1 per route + router-level handlers in app.js (health,
  // ready, metrics, refresh, logout, revoke, live). Count route layers via
  // the route table; router stack size is measured at runtime, not here.
  return { routeFiles, routeDefinitions: total, mutatingRoutes: mutating };
}

function collectDatabase(rootDir) {
  const migDir = path.join(rootDir, 'database', 'migrations');
  const migrations = list(migDir, '.sql').concat(list(path.join(migDir, 'archive'), '.sql').map((f) => `archive/${f}`));
  const tableRe = /CREATE TABLE(?: IF NOT EXISTS)?\s+`?([A-Za-z0-9_]+)`?/g;
  const names = new Set();
  const audit = new Set();
  const addSource = (text) => {
    for (const m of text.matchAll(tableRe)) {
      names.add(m[1]);
      if (m[1].endsWith('_audit')) audit.add(m[1]);
    }
  };
  const schemaPath = path.join(rootDir, 'database', 'schema.sql');
  if (existsSync(schemaPath)) addSource(readFileSync(schemaPath, 'utf8'));
  for (const f of migrations) {
    addSource(readFileSync(path.join(migDir, f), 'utf8'));
  }
  const schemaTables = existsSync(schemaPath)
    ? (readFileSync(schemaPath, 'utf8').match(/^CREATE TABLE/gm) || []).length
    : 0;
  return { migrations: migrations.length, uniqueTables: names.size, auditTables: audit.size, schemaTables };
}

function collectActions(rootDir) {
  const routesDir = path.join(rootDir, 'middleware', 'src', 'routes');
  const found = new Map();
  const add = (file, src) => {
    for (const m of src.matchAll(/action:\s*'([A-Z0-9_]+)'/g)) {
      if (!found.has(m[1])) found.set(m[1], new Set());
      found.get(m[1]).add(file);
    }
  };
  for (const f of list(routesDir, '.js').filter((x) => x !== 'index.js')) {
    add(f, readFileSync(path.join(routesDir, f), 'utf8'));
  }
  const appPath = path.join(rootDir, 'middleware', 'src', 'app.js');
  if (existsSync(appPath)) add('app.js', readFileSync(appPath, 'utf8'));

  const covered = new Set();
  const addCovered = (a) => {
    if (/^[A-Z][A-Z0-9_]+$/.test(a)) covered.add(a);
  };
  for (const dir of [path.join(rootDir, 'tests', 'db'), path.join(rootDir, 'tests', 'integration')]) {
    if (!existsSync(dir)) continue;
    for (const f of list(dir, '.sh')) {
      const src = readFileSync(path.join(dir, f), 'utf8');
      for (const m of src.matchAll(/run_cobol\s+"([A-Z][A-Z0-9_]+)/g)) addCovered(m[1]);
    }
  }
  const casesDir = path.join(rootDir, 'tests', 'cobol', 'cases');
  if (existsSync(casesDir)) {
    for (const f of list(casesDir, '.cases')) {
      for (const line of readFileSync(path.join(casesDir, f), 'utf8').split('\n')) {
        const t = line.trim();
        if (!t || t.startsWith('#') || !t.includes('@@')) continue;
        const parts = t.split('@@');
        if (parts.length < 3) continue;
        addCovered(parts[2].split('|')[0].trim());
      }
    }
  }
  const baselinePath = path.join(rootDir, 'tests', 'action_test_coverage_baseline.txt');
  let baseline = 0;
  if (existsSync(baselinePath)) {
    for (const line of readFileSync(baselinePath, 'utf8').split('\n')) {
      const t = line.trim();
      if (t && !t.startsWith('#')) baseline += 1;
    }
  }
  const shellCovered = [...found.keys()].filter((a) => covered.has(a)).length;
  return {
    routeActions: found.size,
    shellCovered: shellCovered,
    untested: found.size - shellCovered,
    baselineEntries: baseline,
  };
}

function collectDispatch(rootDir) {
  const mainLogic = path.join(rootDir, 'cobol', 'src', 'main_logic.cob');
  if (!existsSync(mainLogic)) return { dispatchEntries: 0, dispatchProblems: ['main_logic.cob missing'] };
  const { entries, problems } = parseDispatchTable(loadDispatchSource(rootDir));
  return { dispatchEntries: entries.length, dispatchProblems: problems };
}

function fileBytes(p) {
  try {
    return statSync(p).size;
  } catch {
    return null;
  }
}

function collectArtifacts(rootDir) {
  return {
    schemaFullBytes: fileBytes(path.join(rootDir, 'database', 'schema_full.sql')),
    fieldOrderBytes: fileBytes(path.join(rootDir, 'tests', 'contracts', 'route_field_order.json')),
  };
}

function gitCommit(rootDir) {
  try {
    return execSync('git rev-parse --short HEAD', { cwd: rootDir, encoding: 'utf8' }).trim();
  } catch {
    return 'unknown';
  }
}

export function audit(rootDir = root) {
  const cobol = collectCobol(rootDir);
  const gateway = collectGateway(rootDir);
  const db = collectDatabase(rootDir);
  const actions = collectActions(rootDir);
  const dispatch = collectDispatch(rootDir);
  const artifacts = collectArtifacts(rootDir);
  return {
    generatedAt: new Date().toISOString(),
    commit: gitCommit(rootDir),
    cobol,
    gateway,
    database: db,
    actions,
    dispatchEntries: dispatch.dispatchEntries,
    dispatchProblems: dispatch.dispatchProblems,
    artifacts,
  };
}

export function baselineRows(stats) {
  const fmt = (n) => (n === null || n === undefined ? '—' : Number(n).toLocaleString('en-US'));
  const kb = (n) => (n === null || n === undefined ? '—' : `${(n / 1024).toFixed(1)} KB`);
  return [
    ['COBOL', 'source files', fmt(stats.cobol.files)],
    ['COBOL', 'modules (excl. dispatcher)', fmt(stats.cobol.modules)],
    ['COBOL', 'lines', fmt(stats.cobol.loc)],
    ['COBOL', 'files with exactly 669 lines', fmt(stats.cobol.exact669)],
    ['COBOL', 'canonical 9-action clones', fmt(stats.cobol.canonical9)],
    ['Gateway', 'route files', fmt(stats.gateway.routeFiles)],
    ['Gateway', 'route definitions', fmt(stats.gateway.routeDefinitions)],
    ['Gateway', 'mutating routes', fmt(stats.gateway.mutatingRoutes)],
    ['Database', 'migrations', fmt(stats.database.migrations)],
    ['Database', 'unique tables', fmt(stats.database.uniqueTables)],
    ['Database', 'audit tables', fmt(stats.database.auditTables)],
    ['Database', 'tables in schema.sql', fmt(stats.database.schemaTables)],
    ['Actions', 'route actions', fmt(stats.actions.routeActions)],
    ['Actions', 'shell-covered', fmt(stats.actions.shellCovered)],
    ['Actions', 'untested (route minus shell)', fmt(stats.actions.untested)],
    ['Actions', 'baseline entries', fmt(stats.actions.baselineEntries)],
    ['Dispatch', 'entries', fmt(stats.dispatchEntries)],
    ['Dispatch', 'problems', fmt(stats.dispatchProblems.length)],
    ['Artifacts', 'database/schema_full.sql', kb(stats.artifacts.schemaFullBytes)],
    ['Artifacts', 'tests/contracts/route_field_order.json', kb(stats.artifacts.fieldOrderBytes)],
  ];
}

export function renderMarkdown(stats) {
  const rows = baselineRows(stats)
    .map(([a, m, v]) => `| ${a} | ${m} | ${v} |`)
    .join('\n');
  return `# Complexity Baseline

> Generated by \`scripts/audit_complexity.mjs\`. Do not edit by hand; run
> \`node scripts/audit_complexity.mjs --write\` after a reviewed change.

- Generated at: ${stats.generatedAt}
- Commit: \`${stats.commit}\`

| Area | Metric | Value |
| --- | --- | ---: |
${rows}
`;
}

export function parseBaselineMarkdown(doc) {
  const rows = new Map();
  for (const line of doc.split('\n')) {
    const m = line.match(/^\| ([^|]+) \| ([^|]+) \| ([^|]+) \|$/);
    if (!m || m[1].trim() === 'Area') continue;
    rows.set(`${m[1].trim()} | ${m[2].trim()}`, m[3].trim());
  }
  return rows;
}

export function checkBaseline(rootDir = root) {
  const doc = readFileSync(path.join(rootDir, 'docs', 'COMPLEXITY_BASELINE.md'), 'utf8');
  const recorded = parseBaselineMarkdown(doc);
  const failures = [];
  for (const [area, metric, value] of baselineRows(audit(rootDir))) {
    const key = `${area} | ${metric}`;
    if (!recorded.has(key)) {
      failures.push(`${key}: missing from docs/COMPLEXITY_BASELINE.md`);
    } else if (recorded.get(key) !== value) {
      failures.push(`${key}: recorded ${recorded.get(key)}, tree has ${value}`);
    }
  }
  return failures;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (check) {
    const failures = checkBaseline(root);
    if (failures.length) {
      console.error('FAIL: docs/COMPLEXITY_BASELINE.md is stale (regenerate deliberately with --write after review):');
      for (const f of failures) console.error(`  ${f}`);
      process.exit(1);
    }
    console.log(`OK: complexity baseline holds (${baselineRows(audit(root)).length} metrics)`);
  } else {
    const stats = audit(root);
    if (write) {
      const doc = renderMarkdown(stats);
      writeFileSync(path.join(root, 'docs', 'COMPLEXITY_BASELINE.md'), doc);
      console.log(`Wrote docs/COMPLEXITY_BASELINE.md (${stats.cobol.modules} modules, commit ${stats.commit})`);
    } else if (mode === 'markdown') {
      console.log(renderMarkdown(stats));
    } else {
      console.log(JSON.stringify(stats, null, 2));
    }
  }
}
