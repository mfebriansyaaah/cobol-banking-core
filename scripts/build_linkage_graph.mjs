// Core linkage graph builder (PR-009, linkage-only).
//
// Scores every COBOL module L0-L3 by its business linkage to the core
// core anchors defined in manifest/linkage.json. All parsing is textual; nothing is
// imported as code.
//
// Scoring (see docs/LINKAGE.md):
//   L3 - core anchor module, or money-table touch (accounts/ledger/journal/GL)
//        with depth (>=2 business tables or a money-action literal) plus a
//        DB/table/integration test proving it.
//   L2 - any business-table reference, CALL into a core anchor module, or
//        money-action literal, plus a test proving it.
//   L1 - references only users/currencies/ref_* (incl. the ALLOW-ADMIN
//        role lookup, which is NOT linkage), or linked code with no test.
//   L0 - no business linkage at all (own generic tables only, or nothing).
//   UTILITY - utility helper listed in linkage.json (never a retire candidate).
//
// Usage:
//   node scripts/build_linkage_graph.mjs --json [--root DIR]
//   node scripts/build_linkage_graph.mjs --markdown [--root DIR]
//   node scripts/build_linkage_graph.mjs --write [--root DIR]
//   node scripts/build_linkage_graph.mjs --write-baseline [--root DIR]
// --write refreshes manifest/linkage_graph.json and docs/LINKAGE.md.
// --write-baseline (re)writes tests/linkage_baseline.txt with the current
// L0/L1 set. Use it once at introduction; afterwards the baseline must only
// shrink (see scripts/check_linkage.mjs). Never use it to green CI.
// Exit: 0 ok, 2 usage error.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseDispatchTable, loadDispatchSource } from './lib/dispatch_table.mjs';

const args = process.argv.slice(2);
let root = '.';
let mode = 'json';
let write = false;
let writeBaseline = false;
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--json') mode = 'json';
  else if (a === '--markdown') mode = 'markdown';
  else if (a === '--write') write = true;
  else if (a === '--write-baseline') writeBaseline = true;
  else if (a === '--root') {
    root = args[i + 1] ?? root;
    i += 1;
  } else if (a === '--help' || a === '-h') {
    console.log('usage: build_linkage_graph.mjs [--json|--markdown] [--write] [--write-baseline] [--root DIR]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
root = path.resolve(root);

function loadLinkage(rootDir) {
  const p = path.join(rootDir, 'manifest', 'linkage.json');
  if (!existsSync(p)) {
    console.error('FAIL: manifest/linkage.json missing');
    process.exit(2);
  }
  return JSON.parse(readFileSync(p, 'utf8'));
}

const isRefish = (t) => t === 'users' || t === 'currencies' || t.startsWith('ref_');

function extractTables(source) {
  const out = new Set();
  for (const m of source.matchAll(/\b(?:FROM|JOIN|INTO|UPDATE)\s+`?([A-Za-z0-9_]+)`?/g)) {
    // COBOL loop bounds (PERFORM VARYING i FROM 256 ...) are not tables.
    if (/^\d+$/.test(m[1])) continue;
    out.add(m[1].toLowerCase());
  }
  return out;
}

function extractCalls(source) {
  const out = new Set();
  for (const m of source.matchAll(/CALL\s+"([a-z_]+)"/g)) {
    out.add(m[1]);
  }
  return out;
}

function extractActionLiterals(source) {
  const out = new Set();
  for (const m of source.matchAll(/"([A-Z][A-Z0-9_]{2,})"/g)) {
    out.add(m[1]);
  }
  return out;
}

function testEvidence(rootDir, base) {
  const out = [];
  if (existsSync(path.join(rootDir, 'tests', 'db', `${base}_db_tests.sh`))) out.push(`tests/db/${base}_db_tests.sh`);
  if (existsSync(path.join(rootDir, 'tests', 'cobol', 'cases', `${base}.cases`)))
    out.push(`tests/cobol/cases/${base}.cases`);
  if (existsSync(path.join(rootDir, 'tests', 'integration'))) {
    for (const f of readdirSync(path.join(rootDir, 'tests', 'integration'))
      .filter((x) => x.endsWith('.sh') && x.startsWith(base))
      .sort()) {
      out.push(`tests/integration/${f}`);
    }
  }
  return out;
}

// Route file -> primary COBOL module via longest-prefix dispatch match on
// the file's actions (same semantics as the COBOL dispatcher). Falls back
// to <base>_core / <base> filename convention.
function resolveRouteModules(rootDir, dispatchEntries, cobolModules) {
  const byPrefix = [...dispatchEntries].sort((a, b) => b.prefix.length - a.prefix.length);
  const programOf = (action) => {
    const hit = byPrefix.find((e) => action.startsWith(e.prefix));
    return hit ? hit.program : null;
  };
  const routesDir = path.join(rootDir, 'middleware', 'src', 'routes');
  const out = {};
  const unresolved = [];
  const addFile = (file, src) => {
    const actions = [...src.matchAll(/action:\s*'([A-Z0-9_]+)'/g)].map((m) => m[1]);
    if (actions.length === 0) return; // no routes defined here (e.g. barrel, empty app.js)
    const votes = new Map();
    for (const a of actions) {
      const program = programOf(a);
      if (program) votes.set(program, (votes.get(program) ?? 0) + 1);
    }
    if (votes.size) {
      out[file] = [...votes.entries()].sort((a, b) => b[1] - a[1])[0][0];
      return;
    }
    const base = file.replace(/\.js$/, '');
    for (const candidate of [`${base}_core`, base]) {
      if (cobolModules.includes(candidate)) {
        out[file] = candidate;
        return;
      }
    }
    unresolved.push(file);
  };
  if (existsSync(routesDir)) {
    for (const f of readdirSync(routesDir)
      .filter((x) => x.endsWith('.js') && x !== 'index.js')
      .sort()) {
      addFile(f, readFileSync(path.join(routesDir, f), 'utf8'));
    }
  }
  const appPath = path.join(rootDir, 'middleware', 'src', 'app.js');
  if (existsSync(appPath)) addFile('app.js', readFileSync(appPath, 'utf8'));
  return { routeModules: out, unresolvedRoutes: unresolved };
}

function entryForModule(module, source, src, ctx) {
  const { businessTables, moneyTables, moneyActions, coreModules, rootDir } = ctx;
  const tables = extractTables(src);
  const biz = [...tables].filter((t) => businessTables.has(t)).sort();
  const money = biz.filter((t) => moneyTables.has(t));
  const calls = [...extractCalls(src)].filter((c) => coreModules.has(c)).sort();
  const lits = [...extractActionLiterals(src)].filter((a) => moneyActions.has(a)).sort();
  const base = module.endsWith('_core') ? module.slice(0, -5) : module;
  const evidence = testEvidence(rootDir, base);
  const tested = evidence.length > 0;
  const entry = {
    module,
    source,
    businessTables: biz,
    coreCalls: calls,
    coreActions: lits,
    hasTests: tested,
    testEvidence: evidence,
  };
  return { entry, tables, biz, money, calls, lits, tested };
}

function linkageFor({ tables, biz, money, calls, lits, tested }) {
  if (money.length > 0 && (biz.length >= 2 || lits.length > 0) && tested) {
    return { linkageLevel: 'L3', reason: `money-table touch (${money.join(', ')}) with depth + test` };
  }
  if ((biz.length > 0 || calls.length > 0 || lits.length > 0) && tested) {
    const parts = [];
    if (biz.length) parts.push(`tables ${biz.join(', ')}`);
    if (calls.length) parts.push(`calls ${calls.join(', ')}`);
    if (lits.length) parts.push(`actions ${lits.join(', ')}`);
    return { linkageLevel: 'L2', reason: `business link (${parts.join('; ')}) + test` };
  }
  if (tables.size > 0 && [...tables].every(isRefish)) {
    return { linkageLevel: 'L1', reason: 'reference-only (users/currencies/ref_*)' };
  }
  if ((biz.length > 0 || calls.length > 0 || lits.length > 0) && !tested) {
    return { linkageLevel: 'L1', reason: 'linked code with no DB/table/integration test (downgraded)' };
  }
  return {
    linkageLevel: 'L0',
    reason: tables.size > 0 ? 'own domain tables only, no core link' : 'no table references at all',
  };
}

function scoreModule(module, source, src, ctx) {
  const { coreModules, utilityModules } = ctx;
  if (coreModules.has(module)) {
    return {
      module,
      source,
      linkageLevel: 'L3',
      businessTables: [],
      coreCalls: [],
      coreActions: [],
      hasTests: true,
      testEvidence: [],
      reason: 'Core anchor module',
    };
  }
  if (utilityModules.has(module)) {
    return {
      module,
      source,
      linkageLevel: 'UTILITY',
      businessTables: [],
      coreCalls: [],
      coreActions: [],
      hasTests: true,
      testEvidence: [],
      reason: 'Utility module (never a retire candidate)',
    };
  }
  const data = entryForModule(module, source, src, ctx);
  return { ...data.entry, ...linkageFor(data) };
}

function attachRouteFiles(modules, rootDir, cobolModules) {
  const mainLogic = path.join(rootDir, 'cobol', 'src', 'main_logic.cob');
  const dispatchEntries = existsSync(mainLogic) ? parseDispatchTable(loadDispatchSource(rootDir)).entries : [];
  const { routeModules, unresolvedRoutes } = resolveRouteModules(rootDir, dispatchEntries, cobolModules);
  for (const m of modules) {
    m.routeFiles = Object.entries(routeModules)
      .filter(([, program]) => program === m.module)
      .map(([file]) => file)
      .sort();
  }
  return { routeModules, unresolvedRoutes };
}

export function buildGraph(rootDir = root) {
  const linkage = loadLinkage(rootDir);
  const coreModules = new Set(linkage.coreModules || []);
  const utilityModules = new Set(linkage.utilityModules || []);
  const businessTables = new Set((linkage.businessTables || []).map((t) => t.toLowerCase()));
  const moneyTables = new Set((linkage.moneyTables || []).map((t) => t.toLowerCase()));
  const moneyActions = new Set(linkage.moneyActions || []);

  const cobolDir = path.join(rootDir, 'cobol', 'src');
  const sources = existsSync(cobolDir)
    ? readdirSync(cobolDir)
        .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob')
        .sort()
    : [];
  const cobolModules = sources.map((f) => f.replace(/\.cob$/, ''));

  const ctx = { coreModules, utilityModules, businessTables, moneyTables, moneyActions, rootDir };
  const modules = sources.map((source) => {
    const module = source.replace(/\.cob$/, '');
    const src = readFileSync(path.join(cobolDir, source), 'utf8');
    return scoreModule(module, source, src, ctx);
  });

  const { routeModules, unresolvedRoutes } = attachRouteFiles(modules, rootDir, cobolModules);

  const summary = { L3: 0, L2: 0, L1: 0, L0: 0, UTILITY: 0 };
  for (const m of modules) summary[m.linkageLevel] += 1;
  return { modules, routeModules, unresolvedRoutes, summary };
}

function gitCommit(rootDir) {
  try {
    return execSync('git rev-parse --short HEAD', { cwd: rootDir, encoding: 'utf8' }).trim();
  } catch {
    return 'unknown';
  }
}

export function renderMarkdown(graph, commit = 'unknown', generatedAt = new Date().toISOString()) {
  const rows = graph.modules.map(
    (m) =>
      `| \`${m.module}\` | ${m.linkageLevel} | ${m.businessTables.join(', ') || '—'} | ${m.coreCalls.join(', ') || '—'} | ${m.routeFiles.length} | ${m.reason} |`,
  );
  return `# Core Linkage

> Generated by \`scripts/build_linkage_graph.mjs\`. Do not edit by hand; run
> \`node scripts/build_linkage_graph.mjs --write\` after a reviewed change.
> Scoring policy: [module linkage](MODULE_LINKAGE.md) (core
> linkage policy). Manual reclassification happens in PR-010
> (\`manifest/domain_status.json\`), not by editing this file.

- Generated at: ${generatedAt}
- Commit: \`${commit}\`

| Level | Modules |
| --- | ---: |
| L3 (core transaction) | ${graph.summary.L3} |
| L2 (business reference) | ${graph.summary.L2} |
| L1 (weak / untested link) | ${graph.summary.L1} |
| L0 (isolated) | ${graph.summary.L0} |
| UTILITY | ${graph.summary.UTILITY} |

Unresolved route files: ${graph.unresolvedRoutes.length ? graph.unresolvedRoutes.join(', ') : 'none'}.

| Module | Level | Business tables | Core calls | Route files | Reason |
| --- | --- | --- | --- | ---: | --- |
${rows.join('\n')}
`;
}

export function baselineText(graph) {
  const header = [
    '# Core linkage baseline (ratchet).',
    '#',
    '# Every L0/L1 module recorded here exists today without a proven core',
    '# business link. The gate (scripts/check_linkage.mjs) fails on:',
    '#   - unlisted modules (new L0/L1 code without a test-backed link),',
    '#   - stale entries (module now L2/L3: link proven, entry left behind),',
    '#   - dead entries (module file removed).',
    '# This baseline must only shrink (PR-010A..D retire the entries).',
    '# Never add an entry to make CI green.',
    '',
  ];
  const lines = graph.modules
    .filter((m) => m.linkageLevel === 'L0' || m.linkageLevel === 'L1')
    .map((m) => `${m.module} ${m.linkageLevel}`);
  return `${header.join('\n')}${lines.join('\n')}\n`;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const graph = buildGraph(root);
  if (write) {
    const generatedAt = new Date().toISOString();
    const commit = gitCommit(root);
    const payload = {
      generatedAt,
      commit,
      linkageSource: 'manifest/linkage.json',
      summary: graph.summary,
      modules: graph.modules,
    };
    // Route resolution is tree-derived metadata for PR-010; the gate only
    // asserts resolvability, so it lives outside the synced modules array.
    payload.routeModules = graph.routeModules;
    payload.unresolvedRoutes = graph.unresolvedRoutes;
    writeFileSync(path.join(root, 'manifest', 'linkage_graph.json'), `${JSON.stringify(payload, null, 2)}\n`);
    writeFileSync(path.join(root, 'docs', 'LINKAGE.md'), renderMarkdown(graph, commit, generatedAt));
    console.log(
      `Wrote manifest/linkage_graph.json, docs/LINKAGE.md (L3 ${graph.summary.L3}, L2 ${graph.summary.L2}, L1 ${graph.summary.L1}, L0 ${graph.summary.L0})`,
    );
  }
  if (writeBaseline) {
    writeFileSync(path.join(root, 'tests', 'linkage_baseline.txt'), baselineText(graph));
    const n = graph.modules.filter((m) => m.linkageLevel === 'L0' || m.linkageLevel === 'L1').length;
    console.log(`Wrote tests/linkage_baseline.txt (${n} L0/L1 entries)`);
  }
  if (!write && !writeBaseline) {
    if (mode === 'markdown') console.log(renderMarkdown(graph, gitCommit(root)));
    else console.log(JSON.stringify({ ...graph, generatedAt: new Date().toISOString() }, null, 2));
  }
}
