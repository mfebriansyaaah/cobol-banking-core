// Clone budget ratchet (PR-002): no new template clones without a proven
// Tier-1 business link.
//
// A new `cobol/src/*_core.cob` fails this gate when it looks like a
// cost_center_core.cob clone AND its linkage level (manifest/tier1_links.json,
// PR-009) is L0/L1. "Looks like a clone" is any of:
//   - canonical 9-action shape (CREATE/LIST/GET/CALC/UPDATE/DELETE/SUMMARY/
//     AUDIT/VALIDATE suffices), same definition as scripts/audit_complexity.mjs,
//   - line-set Jaccard similarity >= 0.90 against the template after
//     normalizing string literals, numbers, and underscore identifiers,
//   - exactly 669 lines (the frozen template size).
// The template file itself (cost_center_core.cob) is excluded: it is the
// canonical source, not a new clone.
//
// Clone-shaped but L2/L3 modules only warn: the linkage test already proves
// a core link, but a reviewer should confirm the link is real.
//
// Baseline (tests/clone_baseline.txt) records every existing clone-like L0/L1
// module with its linkage level. It must only shrink (PR-010A..D retire the
// entries). Never add an entry to make CI green.
//
// Usage:
//   node scripts/check_clone_budget.mjs [--root DIR] [--write]
//   --write rewrites the baseline with the current clone-like L0/L1 set
//   (use once at introduction; afterwards use it only to drop retired or
//   newly-linked modules, never to admit a new clone).
// Exit: 0 ok, 1 mismatch, 2 usage error.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

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
    console.log('usage: check_clone_budget.mjs [--root DIR] [--write]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
root = path.resolve(root);

export const TEMPLATE = 'cost_center_core.cob';
export const TEMPLATE_LINES = 669;
export const SIM_THRESHOLD = 0.9;
const CANONICAL_9 = ['AUDIT', 'CALC', 'CREATE', 'DELETE', 'GET', 'LIST', 'SUMMARY', 'UPDATE', 'VALIDATE'];
const BASELINE_RE = /^([A-Za-z0-9_]+)\s+lines=(\d+)\s+shape=(CLONE9|OTHER)\s+sim=(\d\.\d\d)\s+level=(L0|L1)$/;

const baselinePath = path.join(root, 'tests', 'clone_baseline.txt');

function normalizeLine(line) {
  // COBOL escapes a quote by doubling it, so a naive "[^"]*" would split one
  // literal into fragments and tank similarity for identical clones.
  return line
    .replace(/"([^"]|"")*"/g, '"STR"')
    .replace(/\b\d+\b/g, 'N')
    .replace(/\b[A-Za-z][A-Za-z0-9_]*_[A-Za-z0-9_]+\b/g, 'IDENT')
    .trim()
    .replace(/\s+/g, ' ');
}

function lineSet(text) {
  return new Set(
    text
      .split('\n')
      .map(normalizeLine)
      .filter((l) => l !== ''),
  );
}

function jaccard(a, b) {
  let inter = 0;
  for (const x of a) if (b.has(x)) inter += 1;
  return inter / (a.size + b.size - inter);
}

function cobolActions(source) {
  const out = [];
  for (const m of source.matchAll(/WHEN LS-CMD-ACTION\(1:\d+\) = "([A-Z0-9_]+)"/g)) out.push(m[1]);
  return out;
}

function isCanonical9(actions) {
  const std = new Set([...CANONICAL_9, 'ALLO', 'CLOSE']);
  const suffixes = [...new Set(actions.map((a) => a.split('_').pop()).filter((s) => std.has(s)))].sort();
  return JSON.stringify(suffixes) === JSON.stringify(CANONICAL_9);
}

function countLines(file) {
  const text = readFileSync(file, 'utf8');
  return text.split('\n').length - (text.endsWith('\n') ? 1 : 0);
}

function loadLinkage(rootDir) {
  const p = path.join(rootDir, 'manifest', 'tier1_links.json');
  if (!existsSync(p)) {
    console.error('FAIL: manifest/tier1_links.json missing (run scripts/build_tier1_graph.mjs --write)');
    process.exit(1);
  }
  const data = JSON.parse(readFileSync(p, 'utf8'));
  return new Map((data.modules || []).map((m) => [m.module, m.linkageLevel]));
}

function loadBaseline() {
  if (!existsSync(baselinePath)) return { order: [], levels: new Map(), raw: [] };
  const raw = readFileSync(baselinePath, 'utf8').split('\n');
  const order = [];
  const levels = new Map();
  for (const line of raw) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const m = t.match(BASELINE_RE);
    if (!m) {
      console.error(`FAIL: malformed baseline line: ${line}`);
      process.exit(2);
    }
    if (levels.has(m[1])) {
      console.error(`FAIL: duplicate baseline entries: ${m[1]}`);
      process.exit(2);
    }
    levels.set(m[1], m[5]);
    order.push(m[1]);
  }
  return { order, levels, raw };
}

export function analyze(rootDir = root) {
  const linkage = loadLinkage(rootDir);
  const cobolDir = path.join(rootDir, 'cobol', 'src');
  const templatePath = path.join(cobolDir, TEMPLATE);
  if (!existsSync(templatePath)) {
    console.error(`FAIL: ${templatePath} missing (cannot score clone similarity)`);
    process.exit(1);
  }
  const template = lineSet(readFileSync(templatePath, 'utf8'));
  const files = readdirSync(cobolDir)
    .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob' && f !== TEMPLATE)
    .sort();
  return files.map((file) => {
    const module = file.replace(/\.cob$/, '');
    const src = readFileSync(path.join(cobolDir, file), 'utf8');
    const lines = countLines(path.join(cobolDir, file));
    const shape = isCanonical9(cobolActions(src)) ? 'CLONE9' : 'OTHER';
    const sim = jaccard(template, lineSet(src));
    const level = linkage.get(module) ?? null;
    const cloneLike = shape === 'CLONE9' || sim >= SIM_THRESHOLD || lines === TEMPLATE_LINES;
    return { module, file, lines, shape, sim, level, cloneLike };
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const rows = analyze(root);
  const { order: recorded, levels, raw } = loadBaseline();
  const isLow = (level) => level === 'L0' || level === 'L1';

  if (write) {
    const want = new Map(rows.filter((r) => r.cloneLike && isLow(r.level)).map((r) => [r.module, r]));
    const out = [];
    const seen = new Set();
    for (const line of raw) {
      const t = line.trim();
      if (!t || t.startsWith('#')) {
        out.push(line);
        continue;
      }
      const module = t.split(/\s+/)[0];
      if (seen.has(module)) continue;
      seen.add(module);
      if (want.has(module)) {
        const r = want.get(module);
        out.push(`${r.module} lines=${r.lines} shape=${r.shape} sim=${r.sim.toFixed(2)} level=${r.level}`);
      }
      // else: stale or dead entry -> drop it (reported below when not writing).
    }
    for (const [module, r] of [...want].filter(([m]) => !seen.has(m)).sort()) {
      out.push(`${module} lines=${r.lines} shape=${r.shape} sim=${r.sim.toFixed(2)} level=${r.level}`);
    }
    writeFileSync(baselinePath, `${out.join('\n').replace(/\n+$/, '')}\n`);
    const added = [...want.keys()].filter((k) => !recorded.includes(k));
    const removed = recorded.filter((k) => !want.has(k));
    console.log(`wrote ${baselinePath}: +${added.length} -${removed.length} (total ${want.size})`);
    process.exit(0);
  }

  let failed = false;
  const unscored = rows
    .filter((r) => r.level === null || r.level === undefined)
    .sort((a, b) => a.module.localeCompare(b.module));
  const unlisted = rows
    .filter((r) => r.cloneLike && isLow(r.level) && !levels.has(r.module))
    .sort((a, b) => a.module.localeCompare(b.module));
  const warned = rows.filter((r) => r.cloneLike && !isLow(r.level) && !levels.has(r.module) && r.level !== 'UTILITY');
  const stale = recorded.filter((m) => {
    const r = rows.find((x) => x.module === m);
    return r && !(r.cloneLike && isLow(r.level));
  });
  const dead = recorded.filter((m) => !rows.some((x) => x.module === m));

  if (unscored.length) {
    failed = true;
    console.error('MODULES MISSING FROM manifest/tier1_links.json (run scripts/build_tier1_graph.mjs --write):');
    for (const r of unscored.slice(0, 30)) console.error(`  ${r.file}`);
    if (unscored.length > 30) console.error(`  ... and ${unscored.length - 30} more`);
  }
  if (unlisted.length) {
    failed = true;
    console.error('NEW CLONES WITHOUT A PROVEN TIER-1 LINK (link it to core, or retire the idea):');
    for (const r of unlisted.slice(0, 30)) {
      console.error(`  ${r.file}: ${r.lines} lines, ${r.shape}, sim ${r.sim.toFixed(2)}, ${r.level ?? 'unscored'}`);
    }
    if (unlisted.length > 30) console.error(`  ... and ${unlisted.length - 30} more`);
  }
  for (const r of warned) {
    console.error(
      `NOTE: ${r.file} is clone-shaped (${r.shape}, sim ${r.sim.toFixed(2)}) but ${r.level}-linked; reviewer should confirm the link is real`,
    );
  }
  if (stale.length) {
    failed = true;
    console.error('BASELINE ENTRIES THAT ARE NO LONGER CLONE-LIKE L0/L1 (remove them):');
    for (const m of stale.sort()) console.error(`  ${m}`);
  }
  if (dead.length) {
    failed = true;
    console.error('BASELINE ENTRIES WITH NO MODULE (module removed or renamed?):');
    for (const m of dead.sort()) console.error(`  ${m}`);
  }
  if (failed) {
    console.error(`\nFAIL: clone budget does not match ${baselinePath}`);
    process.exit(1);
  }
  const clones = rows.filter((r) => r.cloneLike && isLow(r.level)).length;
  console.log(`OK: ${clones} clone-like L0/L1 modules, all recorded in baseline (${levels.size} entries)`);
}
