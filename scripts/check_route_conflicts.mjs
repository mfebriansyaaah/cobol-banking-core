// Duplicate-route guard.
//
// Express dispatches to the *first* registered handler for a method+path, so a
// second identical definition is dead code that still looks wired: the route
// exists, the COBOL action exists, the tests exist — and nothing ever calls it.
// Twelve such routes were live in this repo (GPC_*, RSC_*, the whole
// kyc_review module) and no check noticed.
//
// Known conflicts are tracked in tests/known_shadowed_routes.txt so the gate is
// green today and goes red the moment a *new* one appears. The baseline is a
// ratchet: removing a conflict without removing its line also fails, so the
// file cannot quietly rot.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const routesDir = path.join(ROOT, 'middleware', 'src', 'routes');
const baselinePath = path.join(ROOT, 'tests', 'known_shadowed_routes.txt');

const ROUTE_RE = /method:\s*'(get|post|put|patch|delete)'\s*,\s*path:\s*'([^']+)'\s*,\s*action:\s*'([A-Z0-9_]+)'/gs;

function routesIn(source) {
  return [...source.matchAll(ROUTE_RE)].map((m) => ({
    method: m[1].toUpperCase(),
    path: m[2],
    action: m[3],
  }));
}

// Registration order comes from routes/index.js (spread order in ALL_ROUTES),
// because that order decides which handler wins. app.js keeps its own inline
// routes and is registered alongside the barrel.
const fileForExport = new Map();
const fileRoutes = new Map();
for (const f of readdirSync(routesDir)) {
  if (!f.endsWith('.js') || f === 'index.js') continue;
  const src = readFileSync(path.join(routesDir, f), 'utf8');
  const exportName = src.match(/export const (\w+)_ROUTES/);
  if (exportName) fileForExport.set(exportName[1], f);
  fileRoutes.set(f, routesIn(src));
}

const indexSrc = readFileSync(path.join(routesDir, 'index.js'), 'utf8');
const ordered = [];
const seenFiles = new Set();
for (const m of indexSrc.matchAll(/\.\.\.(\w+)_ROUTES/g)) {
  const file = fileForExport.get(m[1]);
  if (!file || seenFiles.has(file)) continue;
  seenFiles.add(file);
  ordered.push({ file, routes: fileRoutes.get(file) || [] });
}
for (const [file, routes] of [...fileRoutes.entries()].sort()) {
  if (seenFiles.has(file)) continue;
  ordered.push({ file, routes });
}

// Inline routes in app.js are registered where buildApp() mounts them; for
// conflict purposes their relative order among themselves is what matters.
const appSrc = readFileSync(path.join(ROOT, 'middleware', 'src', 'app.js'), 'utf8');
ordered.push({ file: 'app.js', routes: routesIn(appSrc) });

const firstSeen = new Map();
const exactConflicts = [];
const shapeConflicts = [];

const segments = (p) => p.split('/');
const isParam = (s) => s.startsWith(':');
const shape = (p) =>
  segments(p)
    .map((s) => (isParam(s) ? ':param' : s))
    .join('/');

// True when the earlier (parameterized) route can match the later path.
// Takes precomputed segment arrays (same length by construction).
function matchesEarlierSegs(aSegs, bSegs) {
  for (let i = 0; i < aSegs.length; i += 1) {
    if (isParam(aSegs[i])) continue;
    if (aSegs[i] !== bSegs[i]) return false;
  }
  return true;
}

const prepared = [];
for (const { file, routes } of ordered) {
  for (const r of routes) {
    const key = `${r.method} ${r.path}`;
    if (firstSeen.has(key)) {
      exactConflicts.push({ key, first: firstSeen.get(key), shadowed: { file, action: r.action } });
    } else {
      firstSeen.set(key, { file, action: r.action });
    }
    // Precompute once: the old loop recomputed split/shape per pair, i.e.
    // O(n^2) string work over 5342 routes (~12s CPU).
    prepared.push({ file, ...r, segs: segments(r.path), shape: shape(r.path) });
  }
}

// Shadowing needs the same method AND segment count, so only pairs inside
// one group can match. Same conflicts, same order, ~2 orders of magnitude
// fewer comparisons.
const groups = new Map();
for (const r of prepared) {
  const gkey = `${r.method}|${r.segs.length}`;
  const earlier = groups.get(gkey) || [];
  for (const prev of earlier) {
    const key = `${r.method} ${r.path}`;
    const sameShape = prev.shape === r.shape;
    if (sameShape && prev.path !== r.path) {
      shapeConflicts.push({
        key,
        kind: 'same-shape',
        first: prev,
        shadowed: { file: r.file, action: r.action },
      });
    } else if (!sameShape && matchesEarlierSegs(prev.segs, r.segs)) {
      shapeConflicts.push({
        key,
        kind: 'param-shadows-static',
        first: prev,
        shadowed: { file: r.file, action: r.action },
      });
    }
  }
  earlier.push(r);
  groups.set(gkey, earlier);
}

const conflicts = [...exactConflicts, ...shapeConflicts];

const baseline = new Set(
  (existsSync(baselinePath) ? readFileSync(baselinePath, 'utf8') : '')
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#')),
);

const found = new Set(conflicts.map((c) => c.key));
const newExact = exactConflicts.filter((c) => !baseline.has(c.key));
const newShape = shapeConflicts.filter((c) => !baseline.has(c.key));
const staleBaseline = [...baseline].filter((k) => !found.has(k));

let failed = false;
if (newExact.length) {
  failed = true;
  console.error('NEW DUPLICATE ROUTES (second registration is unreachable):');
  for (const c of newExact) {
    console.error(`  ${c.key}`);
    console.error(`    registered   : ${c.first.file} -> ${c.first.action}`);
    console.error(`    dead         : ${c.shadowed.file} -> ${c.shadowed.action}`);
  }
}
if (newShape.length) {
  failed = true;
  console.error('NEW ROUTE SHADOWING (parameterized route registered before a static route):');
  for (const c of newShape) {
    console.error(`  ${c.key} is shadowed by ${c.first.method} ${c.first.path}`);
    console.error(`    registered   : ${c.first.file} -> ${c.first.action}`);
    console.error(`    dead         : ${c.shadowed.file} -> ${c.shadowed.action}`);
  }
}
if (staleBaseline.length) {
  failed = true;
  console.error('STALE BASELINE ENTRIES (conflict fixed; remove the line):');
  for (const k of staleBaseline) console.error(`  ${k}`);
}
if (failed) {
  console.error(`\nbaseline: ${baselinePath}`);
  process.exit(1);
}

console.log(
  `OK: ${exactConflicts.length} known duplicate route(s), ${shapeConflicts.length} parameterized shadow(s), no new ones`,
);
