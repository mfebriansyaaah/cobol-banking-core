// Tier-1 linkage graph builder (PR-009).
//
// Scores every COBOL module L0-L3 by its business linkage to the Tier-1
// core defined in manifest/tier1.json. All parsing is textual; nothing is
// imported as code.
//
// Scoring (see docs/TIER1_LINKAGE.md and master plan section 1.4):
//   L3 - Tier-1 module, or money-table touch (accounts/ledger/journal/GL)
//        with depth (>=2 business tables or a money-action literal) plus a
//        DB/table/integration test proving it.
//   L2 - any business-table reference, CALL into a Tier-1 module, or
//        money-action literal, plus a test proving it.
//   L1 - references only users/currencies/ref_* (incl. the ALLOW-ADMIN
//        role lookup, which is NOT linkage), or linked code with no test.
//   L0 - no business linkage at all (own generic tables only, or nothing).
//   UTILITY - Tier-3 helper listed in tier1.json (never a retire candidate).
//
// Usage:
//   node scripts/build_tier1_graph.mjs --json [--root DIR]
//   node scripts/build_tier1_graph.mjs --markdown [--root DIR]
//   node scripts/build_tier1_graph.mjs --write [--root DIR]
//   node scripts/build_tier1_graph.mjs --write-baseline [--root DIR]
// --write refreshes manifest/tier1_links.json and docs/TIER1_LINKAGE.md.
// --write-baseline (re)writes tests/tier1_links_baseline.txt with the current
// L0/L1 set. Use it once at introduction; afterwards the baseline must only
// shrink (see scripts/check_tier1_links.mjs). Never use it to green CI.
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
    console.log('usage: build_tier1_graph.mjs [--json|--markdown] [--write] [--write-baseline] [--root DIR]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
root = path.resolve(root);

function loadTier1(rootDir) {
  const p = path.join(rootDir, 'manifest', 'tier1.json');
  if (!existsSync(p)) {
    console.error('FAIL: manifest/tier1.json missing');
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

export function buildGraph(rootDir = root) {
  const tier1 = loadTier1(rootDir);
  const tier1Modules = new Set(tier1.tier1Modules || []);
  const utilityModules = new Set(tier1.utilityModules || []);
  const businessTables = new Set((tier1.businessTables || []).map((t) => t.toLowerCase()));
  const moneyTables = new Set((tier1.moneyTables || []).map((t) => t.toLowerCase()));
  const moneyActions = new Set(tier1.moneyActions || []);

  const cobolDir = path.join(rootDir, 'cobol', 'src');
  const sources = existsSync(cobolDir)
    ? readdirSync(cobolDir)
        .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob')
        .sort()
    : [];
  const cobolModules = sources.map((f) => f.replace(/\.cob$/, ''));

  const modules = [];
  for (const source of sources) {
    const module = source.replace(/\.cob$/, '');
    const src = readFileSync(path.join(cobolDir, source), 'utf8');
    if (tier1Modules.has(module)) {
      modules.push({
        module,
        source,
        linkageLevel: 'L3',
        businessTables: [],
        t1Calls: [],
        t1Actions: [],
        hasTests: true,
        testEvidence: [],
        reason: 'Tier-1 core module',
      });
      continue;
    }
    if (utilityModules.has(module)) {
      modules.push({
        module,
        source,
        linkageLevel: 'UTILITY',
        businessTables: [],
        t1Calls: [],
        t1Actions: [],
        hasTests: true,
        testEvidence: [],
        reason: 'Tier-3 utility (never a retire candidate)',
      });
      continue;
    }
    const tables = extractTables(src);
    const biz = [...tables].filter((t) => businessTables.has(t)).sort();
    const money = biz.filter((t) => moneyTables.has(t));
    const calls = [...extractCalls(src)].filter((c) => tier1Modules.has(c)).sort();
    const lits = [...extractActionLiterals(src)].filter((a) => moneyActions.has(a)).sort();
    const base = module.endsWith('_core') ? module.slice(0, -5) : module;
    const evidence = testEvidence(rootDir, base);
    const tested = evidence.length > 0;
    let linkageLevel;
    let reason;
    if (money.length > 0 && (biz.length >= 2 || lits.length > 0) && tested) {
      linkageLevel = 'L3';
      reason = `money-table touch (${money.join(', ')}) with depth + test`;
    } else if ((biz.length > 0 || calls.length > 0 || lits.length > 0) && tested) {
      linkageLevel = 'L2';
      const parts = [];
      if (biz.length) parts.push(`tables ${biz.join(', ')}`);
      if (calls.length) parts.push(`calls ${calls.join(', ')}`);
      if (lits.length) parts.push(`actions ${lits.join(', ')}`);
      reason = `business link (${parts.join('; ')}) + test`;
    } else if (tables.size > 0 && [...tables].every(isRefish)) {
      linkageLevel = 'L1';
      reason = 'reference-only (users/currencies/ref_*)';
    } else if ((biz.length > 0 || calls.length > 0 || lits.length > 0) && !tested) {
      linkageLevel = 'L1';
      reason = 'linked code with no DB/table/integration test (downgraded)';
    } else {
      linkageLevel = 'L0';
      reason = tables.size > 0 ? 'own domain tables only, no core link' : 'no table references at all';
    }
    modules.push({
      module,
      source,
      linkageLevel,
      businessTables: biz,
      t1Calls: calls,
      t1Actions: lits,
      hasTests: tested,
      testEvidence: evidence,
      reason,
    });
  }

  const mainLogic = path.join(cobolDir, 'main_logic.cob');
  const dispatchEntries = existsSync(mainLogic) ? parseDispatchTable(loadDispatchSource(rootDir)).entries : [];
  const { routeModules, unresolvedRoutes } = resolveRouteModules(rootDir, dispatchEntries, cobolModules);
  for (const m of modules) {
    m.routeFiles = Object.entries(routeModules)
      .filter(([, program]) => program === m.module)
      .map(([file]) => file)
      .sort();
  }

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
      `| \`${m.module}\` | ${m.linkageLevel} | ${m.businessTables.join(', ') || '—'} | ${m.t1Calls.join(', ') || '—'} | ${m.routeFiles.length} | ${m.reason} |`,
  );
  return `# Tier-1 Linkage

> Generated by \`scripts/build_tier1_graph.mjs\`. Do not edit by hand; run
> \`node scripts/build_tier1_graph.mjs --write\` after a reviewed change.
> Scoring policy: [module classification](module_classification.md) (Tier-1
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

| Module | Level | Business tables | Tier-1 calls | Route files | Reason |
| --- | --- | --- | --- | ---: | --- |
${rows.join('\n')}
`;
}

export function baselineText(graph) {
  const header = [
    '# Tier-1 linkage baseline (ratchet).',
    '#',
    '# Every L0/L1 module recorded here exists today without a proven Tier-1',
    '# business link. The gate (scripts/check_tier1_links.mjs) fails on:',
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
      tier1: 'manifest/tier1.json',
      summary: graph.summary,
      modules: graph.modules,
    };
    // Route resolution is tree-derived metadata for PR-010; the gate only
    // asserts resolvability, so it lives outside the synced modules array.
    payload.routeModules = graph.routeModules;
    payload.unresolvedRoutes = graph.unresolvedRoutes;
    writeFileSync(path.join(root, 'manifest', 'tier1_links.json'), `${JSON.stringify(payload, null, 2)}\n`);
    writeFileSync(path.join(root, 'docs', 'TIER1_LINKAGE.md'), renderMarkdown(graph, commit, generatedAt));
    console.log(
      `Wrote manifest/tier1_links.json, docs/TIER1_LINKAGE.md (L3 ${graph.summary.L3}, L2 ${graph.summary.L2}, L1 ${graph.summary.L1}, L0 ${graph.summary.L0})`,
    );
  }
  if (writeBaseline) {
    writeFileSync(path.join(root, 'tests', 'tier1_links_baseline.txt'), baselineText(graph));
    const n = graph.modules.filter((m) => m.linkageLevel === 'L0' || m.linkageLevel === 'L1').length;
    console.log(`Wrote tests/tier1_links_baseline.txt (${n} L0/L1 entries)`);
  }
  if (!write && !writeBaseline) {
    if (mode === 'markdown') console.log(renderMarkdown(graph, gitCommit(root)));
    else console.log(JSON.stringify({ ...graph, generatedAt: new Date().toISOString() }, null, 2));
  }
}
