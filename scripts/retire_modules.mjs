// Retirement wave executor (PR-010A..D): delete CANDIDATE/DEPRECATED L0/L1
// modules (route + COBOL + tests) without dropping tables.
//
// Safety rules (all verified before any write in --apply):
//   - every listed module is CANDIDATE/DEPRECATED in code_candidates.json and
//     L0/L1 in tier1_links.json; legacy modules and the template are rejected
//     (they have their own PRs / must stay as the similarity reference);
//   - every action in a deleted route file resolves to the deleted module
//     itself (longest-prefix dispatch), and no kept route file, app.js, suite,
//     cases file, probe, bench, or gateway test references a deleted action
//     (the routes.test.js identity map is pruned mechanically first);
//   - tables are NEVER dropped here (PR-010D does that after retention).
//
// --apply deletes files, edits the barrel/build.sh/db.sh/dispatch/baselines,
// prunes the gateway identity-test map, then re-runs every generator
// (manifest, field order, docs stats, linkage graph, domain/code docs) and
// drops dead registry entries. Run the acceptance gates afterwards.
//
// Usage:
//   node scripts/retire_modules.mjs --wave-file manifest/wave_a.json --check
//   node scripts/retire_modules.mjs --wave-file manifest/wave_a.json --apply
// Exit: 0 ok, 1 mismatch/abort, 2 usage error.
import { existsSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseDispatchTable } from './lib/dispatch_table.mjs';
import { collectRoutes } from './lib/route_fields.mjs';

const args = process.argv.slice(2);
let root = '.';
let waveFile = null;
let apply = false;
let includeLegacy = false;
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--wave-file') {
    waveFile = args[i + 1] ?? null;
    i += 1;
  } else if (a === '--apply') apply = true;
  else if (a === '--check') apply = false;
  else if (a === '--include-legacy') includeLegacy = true;
  else if (a === '--root') {
    root = args[i + 1] ?? root;
    i += 1;
  } else if (a === '--help' || a === '-h') {
    console.log('usage: retire_modules.mjs --wave-file FILE [--check|--apply] [--include-legacy] [--root DIR]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
if (!waveFile && process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  console.error('FAIL: --wave-file is required');
  process.exit(2);
}
root = path.resolve(root);

const TEMPLATE_MODULE = 'cost_center_core';
const LEGACY = new Set([
  'collateral_mgmt_core',
  'collateral_repossession_core',
  'collateralized_core',
  'trade_finance_core',
  'documentary_credit_core',
  'bankers_acceptance_core',
  'export_finance_core',
  'import_finance_core',
  'factoring_core',
  'tax_withholding_core',
  'tax_item_core',
  'dispute_management_core',
  'loyalty_program_core',
  'rewards_management_core',
  'points_redemption_core',
  'cashback_core',
  'asset_management_core',
]);

// Files the wave itself regenerates or edits: excluded from the kept-tree
// reference scan (they are handled explicitly below).
const REGEN_PREFIXES = [
  'tests/action_test_coverage_baseline.txt',
  'tests/contracts/route_field_order.json',
  'manifest/modules.json',
  'manifest/tier1_links.json',
  'manifest/domain_status.json',
  'manifest/code_candidates.json',
  'manifest/integration_backlog.json',
  'docs/STATUS.md',
  'docs/MODULE_INDEX.md',
  'docs/TIER1_LINKAGE.md',
  'docs/DOMAIN_STATUS.md',
  'docs/CODE_CANDIDATES.md',
  'docs/INTEGRATION_BACKLOG.md',
  'tests/tier1_links_baseline.txt',
  'tests/clone_baseline.txt',
  'tests/code_candidates_baseline.txt',
  'tests/lib/db.sh',
  'tests/baseline_counts.txt',
  'tests/warning_baseline.txt',
  'middleware/src/routes/index.js',
  'middleware/test/routes.test.js',
  'build.sh',
  'cobol/src/main_logic.cob',
  'README.md',
];

function loadJson(p) {
  if (!existsSync(p)) {
    console.error(`FAIL: ${p} missing`);
    process.exit(1);
  }
  return JSON.parse(readFileSync(p, 'utf8'));
}

function waveActions(rootDir, modules) {
  const out = new Map(); // action -> module
  for (const m of modules) {
    const src = readFileSync(path.join(rootDir, 'cobol', 'src', `${m}.cob`), 'utf8');
    for (const mt of src.matchAll(/WHEN LS-CMD-ACTION\(1:\d+\) = "([A-Z0-9_]+)"/g)) {
      out.set(mt[1].trim(), m);
    }
  }
  return out;
}

function programOf(dispatchEntries, action) {
  const hit = [...dispatchEntries]
    .sort((a, b) => b.prefix.length - a.prefix.length)
    .find((e) => action.startsWith(e.prefix));
  return hit ? hit.program : null;
}

export function rewriteDispatch(mainLogicText, retiredPrograms) {
  const re =
    /^[ \t]*MOVE "([^"]+)" TO D-PREFIX\((\d+)\)\.\n^[ \t]*MOVE (\d+) TO D-PREFIX-LEN\(\d+\)\.\n^[ \t]*MOVE "([^"]+)" TO D-PROGRAM\(\d+\)\.\n/gm;
  const slots = [];
  let m;
  while ((m = re.exec(mainLogicText)) !== null) {
    slots.push({ prefix: m[1], prefixLen: Number(m[3]), program: m[4] });
  }
  if (slots.length === 0) throw new Error('no dispatch slots parsed');
  const kept = slots.filter((s) => !retiredPrograms.has(s.program));
  if (kept.length === slots.length) throw new Error('no dispatch slots matched retired programs');
  const lines = kept.map(
    (s, i) =>
      `            MOVE "${s.prefix}" TO D-PREFIX(${i + 1}).\n` +
      `            MOVE ${s.prefixLen} TO D-PREFIX-LEN(${i + 1}).\n` +
      `            MOVE "${s.program}" TO D-PROGRAM(${i + 1}).\n`,
  );
  const body = mainLogicText.replace(re, () => '__DISPATCH_SLOT__');
  // Replace the run of placeholders (they are contiguous) with new numbering.
  const n = slots.length;
  const placeholderRun = '__DISPATCH_SLOT__'.repeat(1);
  void placeholderRun;
  void n;
  // Simpler: replace each placeholder occurrence in order.
  let idx = 0;
  const rewritten = body.replace(/__DISPATCH_SLOT__/g, () => lines[idx++] ?? '');
  const out = rewritten.replace(/MOVE\s+\d+\s+TO DISPATCH-COUNT\./, `MOVE ${kept.length} TO DISPATCH-COUNT.`);
  return { text: out, removed: slots.length - kept.length, remaining: kept.length };
}

export function pruneBarrel(indexText, files) {
  // One import line per route file, but the local binding may be aliased
  // (`import { CLM_ROUTES as CLAIMS_ROUTES } from './claims_management.js'`),
  // and the same exported name may back a kept file too. Drop by filename,
  // then drop spreads of exactly the removed local names.
  const removedLocals = [];
  let out = indexText;
  for (const file of files) {
    const base = file.replace(/\.js$/, '');
    const lineRe = new RegExp(`^import \\{([^}]*)\\} from '\\./${base}\\.js';\\n`, 'm');
    const m = out.match(lineRe);
    if (m) {
      for (const spec of m[1].split(',')) {
        const parts = spec.trim().split(/\s+as\s+/);
        removedLocals.push(parts[parts.length - 1]);
      }
      out = out.replace(lineRe, '');
    }
  }
  for (const name of removedLocals) {
    out = out.replace(new RegExp(`^\\s*\\.\\.\\.${name},\\n`, 'm'), '');
  }
  return out;
}

export function removeBuildSources(buildText, files) {
  let out = buildText;
  for (const file of files) {
    out = out.replace(new RegExp(`^\\s*cobol/src/${file.replace('.cob', '')}\\.cob \\\\\\n`, 'm'), '');
  }
  return out;
}

export function removeDbResetBlock(dbText, base, stillReferenced) {
  if (stillReferenced) return { text: dbText, removed: false };
  const re = new RegExp(`^db_reset_${base}\\(\\) \\{\\n(?:[^\\n]*\\n)*?\\}\\n\\n?`, 'm');
  if (!re.test(dbText)) return { text: dbText, removed: false };
  return { text: dbText.replace(re, ''), removed: true };
}

export function dropBaselineLines(text, pred) {
  const kept = text.split('\n').filter((line) => {
    const t = line.trim();
    if (!t || t.startsWith('#')) return true;
    return !pred(t);
  });
  return `${kept.join('\n').replace(/\n+$/, '')}\n`;
}

export function pruneTokenIdentityMap(testText, actions) {
  const gone = new Set(actions);
  const lines = testText.split('\n');
  const kept = lines.filter((line) => {
    const m = line.match(/^\s*([A-Z][A-Z0-9_]+):\s*'(?:actor|from)',\s*$/);
    return !(m && gone.has(m[1]));
  });
  return { text: kept.join('\n'), removed: lines.length - kept.length };
}

// Split top-level route objects `{ method: ... }` with spans. Quote-aware
// balanced-brace scan; an opener qualifies when `method` follows the brace
// (same criterion as scripts/lib/route_fields.mjs, plus source spans).
export function splitRouteObjects(src) {
  const out = [];
  for (let i = 0; i < src.length; i += 1) {
    if (src[i] !== '{') continue;
    if (!/^\s*method\s*:/.test(src.slice(i + 1, i + 40))) continue;
    let depth = 0;
    let quote = null;
    let j = i;
    for (; j < src.length; j += 1) {
      const ch = src[j];
      if (quote) {
        if (ch === '\\') {
          j += 1;
          continue;
        }
        if (ch === quote) quote = null;
        continue;
      }
      if (ch === "'" || ch === '"' || ch === '`') {
        quote = ch;
        continue;
      }
      if (ch === '{') depth += 1;
      else if (ch === '}') {
        depth -= 1;
        if (depth === 0) break;
      }
    }
    const body = src.slice(i, j + 1);
    const am = body.match(/action:\s*'([A-Z0-9_]+)'/);
    out.push({ start: i, end: j + 1, body, action: am ? am[1] : null });
    i = j;
  }
  return out;
}

// Remove route objects whose action is being retired. Extends each removed
// span over the adjacent separator comma so the array stays valid.
export function pruneRouteActions(src, goneActions) {
  const gone = new Set(goneActions);
  const objs = splitRouteObjects(src).filter((o) => o.action && gone.has(o.action));
  if (objs.length === 0) return { text: src, removed: 0 };
  const spans = objs.map((o) => {
    let { start, end } = o;
    const after = src.slice(end, end + 40).match(/^(\s*,)?/)[0];
    if (after.includes(',')) {
      end += after.length;
    } else {
      const before = src.slice(Math.max(0, start - 40), start).match(/(,\s*)$/);
      if (before) start -= before[0].length;
    }
    return [start, end];
  });
  spans.sort((a, b) => a[0] - b[0]);
  let out = '';
  let pos = 0;
  for (const [s, e] of spans) {
    out += src.slice(pos, s);
    pos = e;
  }
  out += src.slice(pos);
  // Collapse 3+ consecutive blank lines left behind, keep file tidy.
  out = out.replace(/\n{4,}/g, '\n\n\n');
  return { text: out, removed: objs.length };
}

function routeActionSet(rootDir) {
  const out = new Set();
  const routesDir = path.join(rootDir, 'middleware', 'src', 'routes');
  if (existsSync(routesDir)) {
    for (const f of readdirSync(routesDir).filter((x) => x.endsWith('.js') && x !== 'index.js')) {
      const src = readFileSync(path.join(routesDir, f), 'utf8');
      for (const m of src.matchAll(/action:\s*'([A-Z0-9_]+)'/g)) out.add(m[1]);
    }
  }
  const appPath = path.join(rootDir, 'middleware', 'src', 'app.js');
  if (existsSync(appPath)) {
    const src = readFileSync(appPath, 'utf8');
    for (const m of src.matchAll(/action:\s*'([A-Z0-9_]+)'/g)) out.add(m[1]);
  }
  return out;
}

export function dropDeadActionEntries(rootDir, deletedActions) {
  const abPath = path.join(rootDir, 'tests', 'action_test_coverage_baseline.txt');
  const routed = routeActionSet(rootDir);
  const before = readFileSync(abPath, 'utf8');
  const after = dropBaselineLines(before, (t) => {
    const action = t.split(/\s+/)[0];
    return deletedActions.has(action) || !routed.has(action);
  });
  writeFileSync(abPath, after);
  return before !== after;
}

export function dropStaleShadowedRoutes(rootDir) {
  // A shadowed-route line is stale when its METHOD + path no longer exists in
  // any kept route file. Uses the shared route parser (text only, never
  // imports gateway code), same definition family as the conflicts gate.
  // Conservative: drop a line only when its METHOD + path exists in NO kept
  // route file at all. A path that still exists (even singly) keeps its line;
  // the conflicts gate flags it as stale for deliberate manual removal.
  // This can leave stale lines behind but can never delete a live conflict.
  const live = new Set();
  for (const [key] of collectRoutes(rootDir)) {
    const parts = key.split('::');
    live.add((parts[1] || '').trim());
  }
  const p = path.join(rootDir, 'tests', 'known_shadowed_routes.txt');
  const before = readFileSync(p, 'utf8');
  const after = dropBaselineLines(before, (t) => /^[A-Z]+\s+\//.test(t) && !live.has(t));
  writeFileSync(p, after);
  return before !== after;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const wave = JSON.parse(readFileSync(path.resolve(waveFile), 'utf8'));
  const modules = [...new Set(wave.modules || [])].sort();
  if (modules.length === 0) {
    console.error('FAIL: wave file lists no modules');
    process.exit(1);
  }
  const failures = [];
  const fail = (msg) => {
    console.error(`FAIL: ${msg}`);
    failures.push(msg);
  };

  const candidates = new Map(
    (loadJson(path.join(root, 'manifest', 'code_candidates.json')).candidates || []).map((c) => [c.module, c.status]),
  );
  const links = new Map(
    (loadJson(path.join(root, 'manifest', 'tier1_links.json')).modules || []).map((m) => [m.module, m]),
  );
  for (const m of modules) {
    const st = candidates.get(m);
    if (st !== 'CANDIDATE' && st !== 'DEPRECATED') fail(`${m}: not a CANDIDATE/DEPRECATED code candidate (has ${st})`);
    const level = links.get(m)?.linkageLevel;
    if (level !== 'L0' && level !== 'L1') fail(`${m}: waves only cover L0/L1 (has ${level})`);
    if (LEGACY.has(m) && !includeLegacy) fail(`${m}: legacy module, belongs to PR-011..013 (use --include-legacy)`);
    if (m === TEMPLATE_MODULE) fail(`${m}: canonical template must stay`);
    if (!existsSync(path.join(root, 'cobol', 'src', `${m}.cob`))) fail(`${m}: cobol source missing`);
  }

  const mainLogic = readFileSync(path.join(root, 'cobol', 'src', 'main_logic.cob'), 'utf8');
  const { entries: dispatch } = parseDispatchTable(mainLogic);
  const waveSet = new Set(modules);
  const actions = waveActions(root, modules);

  // Route files: exclusive (every action resolves to a deleted module, file
  // goes away) or shared (kept actions stay; only deleted route objects are
  // pruned). Unresolvable actions fail either way.
  const routeFiles = new Set();
  const sharedPruned = new Map();
  for (const m of modules) {
    for (const f of links.get(m)?.routeFiles || []) routeFiles.add(f);
  }
  // Some modules resolve to no route file (e.g. pure-COBOL actions); scan
  // every route file that mentions a deleted action so shared files like
  // trade_finance.js are classified even when they are nobody's primary.
  {
    const extra = new Set();
    for (const f of readdirSync(path.join(root, 'middleware', 'src', 'routes'))
      .filter((x) => x.endsWith('.js') && x !== 'index.js')
      .sort()) {
      const src = readFileSync(path.join(root, 'middleware', 'src', 'routes', f), 'utf8');
      for (const o of splitRouteObjects(src)) {
        if (o.action && waveSet.has(programOf(dispatch, o.action))) extra.add(f);
      }
    }
    for (const f of extra) routeFiles.add(f);
  }
  for (const f of routeFiles) {
    const src = readFileSync(path.join(root, 'middleware', 'src', 'routes', f), 'utf8');
    const objs = splitRouteObjects(src);
    const owners = new Map();
    for (const o of objs) {
      if (!o.action) continue;
      const owner = programOf(dispatch, o.action);
      if (!owner) fail(`route file ${f}: action ${o.action} has no dispatch entry`);
      else owners.set(o.action, owner);
    }
    const kept = [...owners.values()].some((p) => !waveSet.has(p));
    const gone = [...owners.values()].some((p) => waveSet.has(p));
    if (gone && kept) {
      const pruned = pruneRouteActions(src, new Set([...owners].filter(([, p]) => waveSet.has(p)).map(([a]) => a)));
      if (pruned.removed === 0) fail(`route file ${f}: shared classification but nothing pruned`);
      sharedPruned.set(f, pruned.text);
    } else if (gone && !kept) {
      // exclusive: deleted wholly below
    } else {
      fail(`route file ${f}: contains no deleted actions (not part of this wave)`);
    }
  }
  for (const [action, owner] of actions) {
    if (!programOf(dispatch, action)) fail(`action ${action} (${owner}) has no dispatch entry`);
  }

  // Kept-tree reference scan (regen-managed files handled explicitly below;
  // fixtures and prose docs are self-contained / non-gating).
  const doomed = new Set([`cobol/src/main_logic.cob`]);
  for (const m of modules) {
    const base = m.endsWith('_core') ? m.slice(0, -5) : m;
    doomed.add(`cobol/src/${m}.cob`);
    doomed.add(`tests/db/${base}_db_tests.sh`);
    doomed.add(`tests/cobol/cases/${base}.cases`);
  }
  for (const f of routeFiles) {
    if (!sharedPruned.has(f)) doomed.add(`middleware/src/routes/${f}`);
  }
  const prunedMap = pruneTokenIdentityMap(
    readFileSync(path.join(root, 'middleware', 'test', 'routes.test.js'), 'utf8'),
    new Set(actions.keys()),
  ).text;
  const scanHits = [];
  const tok = /\b[A-Z][A-Z0-9_]{2,}\b/g;
  const skipPrefixes = [...REGEN_PREFIXES, 'docs/', 'tests/perf/README.md'];
  const scanFiles = [];
  const collect = (dir) => {
    for (const f of readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, f.name);
      const rel = path.relative(root, p);
      if (f.isDirectory()) {
        if (['node_modules', '.git', 'fixtures'].includes(f.name)) continue;
        collect(p);
      } else if (/\.(sh|cases|mjs|js|cob|sql)$/.test(f.name) && !doomed.has(rel)) {
        scanFiles.push(rel);
      }
    }
  };
  for (const sroot of ['tests', 'middleware/test', 'middleware/src']) collect(path.join(root, sroot));
  for (const rel of scanFiles) {
    if (skipPrefixes.some((s) => rel === s || rel.startsWith(s))) continue;
    let text = readFileSync(path.join(root, rel), 'utf8');
    if (rel === 'middleware/test/routes.test.js') text = prunedMap;
    if (rel.startsWith('middleware/src/routes/') && sharedPruned.has(path.basename(rel))) {
      text = sharedPruned.get(path.basename(rel));
    }
    const found = new Set(text.match(tok) || []);
    for (const a of found) {
      if (actions.has(a)) scanHits.push(`${rel}: ${a} (${actions.get(a)})`);
    }
  }
  for (const h of scanHits.slice(0, 30)) fail(`kept file references deleted action: ${h}`);
  if (scanHits.length > 30) fail(`... and ${scanHits.length - 30} more kept-tree references`);

  // Plan summary.
  let loc = 0;
  for (const m of modules) {
    const t = readFileSync(path.join(root, 'cobol', 'src', `${m}.cob`), 'utf8');
    loc += t.split('\n').length - (t.endsWith('\n') ? 1 : 0);
  }
  const exclusiveCount = [...routeFiles].filter((f) => !sharedPruned.has(f)).length;
  console.log(
    `wave ${wave.wave || '?'}: ${modules.length} modules, ${exclusiveCount} exclusive + ${sharedPruned.size} shared route files (~${actions.size} actions), ~${loc.toLocaleString('en-US')} COBOL lines`,
  );

  if (failures.length > 0) {
    console.error(`\n${failures.length} eligibility problem(s); refusing to proceed`);
    process.exit(1);
  }
  if (!apply) {
    console.log('OK: wave eligible (dry run, no writes). Re-run with --apply to delete.');
    process.exit(0);
  }

  // ---------------- apply ----------------
  for (const f of routeFiles) {
    if (sharedPruned.has(f)) {
      writeFileSync(path.join(root, 'middleware', 'src', 'routes', f), sharedPruned.get(f));
    } else {
      rmSync(path.join(root, 'middleware', 'src', 'routes', f), { force: true });
    }
  }
  for (const m of modules) {
    const base = m.endsWith('_core') ? m.slice(0, -5) : m;
    rmSync(path.join(root, 'cobol', 'src', `${m}.cob`), { force: true });
    rmSync(path.join(root, 'tests', 'db', `${base}_db_tests.sh`), { force: true });
    rmSync(path.join(root, 'tests', 'cobol', 'cases', `${base}.cases`), { force: true });
  }
  const runNode = (scriptArgs) =>
    execFileSync(process.execPath, scriptArgs, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });

  // Barrel, build list, identity-test map, dispatch table.
  const indexPath = path.join(root, 'middleware', 'src', 'routes', 'index.js');
  const exclusiveFiles = [...routeFiles].filter((f) => !sharedPruned.has(f));
  writeFileSync(indexPath, pruneBarrel(readFileSync(indexPath, 'utf8'), exclusiveFiles));
  const buildPath = path.join(root, 'build.sh');
  writeFileSync(
    buildPath,
    removeBuildSources(
      readFileSync(buildPath, 'utf8'),
      modules.map((m) => `${m}.cob`),
    ),
  );
  const routesTestPath = path.join(root, 'middleware', 'test', 'routes.test.js');
  const pruned = pruneTokenIdentityMap(readFileSync(routesTestPath, 'utf8'), new Set(actions.keys()));
  writeFileSync(routesTestPath, pruned.text);
  console.log(`pruned ${pruned.removed} identity-map entries from middleware/test/routes.test.js`);
  const mlPath = path.join(root, 'cobol', 'src', 'main_logic.cob');
  const mlText = readFileSync(mlPath, 'utf8');
  const stillDispatched = [...waveSet].filter((m) => mlText.includes(`"${m}"`));
  if (stillDispatched.length === 0) {
    console.log('dispatch: already clean (no retired programs remain)');
  } else {
    const rw = rewriteDispatch(mlText, waveSet);
    writeFileSync(mlPath, rw.text);
    console.log(`dispatch: removed ${rw.removed} slots, ${rw.remaining} remain, count updated`);
  }

  // db_reset helpers unused by remaining suites.
  const dbPath = path.join(root, 'tests', 'lib', 'db.sh');
  let dbText = readFileSync(dbPath, 'utf8');
  const remainingSuites = readdirSync(path.join(root, 'tests', 'db'))
    .filter((f) => f.endsWith('.sh'))
    .map((f) => readFileSync(path.join(root, 'tests', 'db', f), 'utf8'));
  let resets = 0;
  for (const m of modules) {
    const base = m.endsWith('_core') ? m.slice(0, -5) : m;
    const used = remainingSuites.some((t) => new RegExp(`^\\s*db_reset_${base}(?:\\s|$)`, 'm').test(t));
    const r = removeDbResetBlock(dbText, base, used);
    dbText = r.text;
    if (r.removed) resets += 1;
  }
  writeFileSync(dbPath, dbText);
  console.log(`db.sh: removed ${resets} unused db_reset helpers`);

  // Count baselines, warning baseline, action baseline (dead entries only).
  const bcPath = path.join(root, 'tests', 'baseline_counts.txt');
  const suiteKeys = new Set(
    modules.map((m) => `db_${(m.endsWith('_core') ? m.slice(0, -5) : m).replace(/-/g, '_')}_tests`),
  );
  writeFileSync(
    bcPath,
    dropBaselineLines(readFileSync(bcPath, 'utf8'), (t) => suiteKeys.has(t.split('=')[0])),
  );
  const wbPath = path.join(root, 'tests', 'warning_baseline.txt');
  writeFileSync(
    wbPath,
    dropBaselineLines(readFileSync(wbPath, 'utf8'), (t) => waveSet.has(t.split('=')[0].replace('.cob', ''))),
  );
  // Dead action entries: deleted-module actions plus any baseline action with
  // no remaining route (same dead definition as the coverage gate, so a
  // renamed-but-routed action like KCP_UPDATE is caught too).
  dropDeadActionEntries(root, actions);
  dropStaleShadowedRoutes(root);
  console.log('baselines: dropped retired suite/warning/action entries');

  // Regenerators (single-source logic lives in each script).
  runNode(['scripts/generate_manifest.mjs', '.']);
  runNode(['scripts/generate_field_order.mjs', '--write', '.']);
  runNode(['scripts/docs_stats.mjs', '--write']);
  runNode(['scripts/build_tier1_graph.mjs', '--write']);
  runNode(['scripts/classify_domains.mjs', '--write-docs', '.']);
  runNode(['scripts/classify_code_candidates.mjs', '--write-docs', '.']);
  runNode(['scripts/check_test_counts.mjs', '--static', '.', '--write']);

  // Registry removals (these registries are hand-maintained; --write only adds).
  for (const [rel, key] of [
    ['manifest/domain_status.json', 'entries'],
    ['manifest/code_candidates.json', 'candidates'],
  ]) {
    const p = path.join(root, rel);
    const data = JSON.parse(readFileSync(p, 'utf8'));
    const before = data[key].length;
    data[key] = data[key].filter((e) => !waveSet.has(e.module));
    data.generatedAt = new Date().toISOString();
    writeFileSync(p, `${JSON.stringify(data, null, 2)}\n`);
    console.log(`${rel}: removed ${before - data[key].length} entries`);
  }
  for (const rel of [
    'tests/tier1_links_baseline.txt',
    'tests/clone_baseline.txt',
    'tests/code_candidates_baseline.txt',
  ]) {
    const p = path.join(root, rel);
    writeFileSync(
      p,
      dropBaselineLines(readFileSync(p, 'utf8'), (t) => waveSet.has(t.split(/\s+/)[0])),
    );
  }
  console.log('baselines: dropped retired ratchet entries');
  console.log('OK: wave applied. Run the acceptance gates next.');
}
