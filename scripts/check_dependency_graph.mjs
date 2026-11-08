// Dependency-graph gate (ADR-0006): enforce one-way layering.
// Allowed directions:
//   src → core-client, telemetry, adapters, routes, auth/validation (own layer)
//   adapters → services, core-client, telemetry, src/validation (shape only)
//   services → telemetry, core-client (never src, never workers, never adapters)
//   workers → core-client, telemetry, services, adapters (never src)
//   core-client → telemetry (counters only), never src/services/workers/adapters
//   telemetry → node builtins only
//   routes → validation only
// server.js is the composition root and may wire everything.
// Usage: node scripts/check_dependency_graph.mjs [root]
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const MW = path.join(ROOT, 'middleware');

const failures = [];
const fail = (m) => failures.push(m);

function listJs(dir) {
  const out = [];
  const walk = (d) => {
    if (!existsSync(d)) return;
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith('.js')) out.push(p);
    }
  };
  walk(dir);
  return out;
}

function stripComments(src) {
  return src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1');
}

function importsOf(src) {
  const clean = stripComments(src);
  const out = [];
  for (const m of clean.matchAll(/import\s+(?:[^'"]+?\s+from\s+)?['"]([^'"]+)['"]/g)) out.push(m[1]);
  for (const m of clean.matchAll(/await\s+import\(\s*['"]([^'"]+)['"]\s*\)/g)) out.push(m[1]);
  return out;
}

function layerOf(file) {
  const rel = path.relative(MW, file);
  if (rel.startsWith('src/routes/')) return 'routes';
  if (rel.startsWith('src/')) return 'src';
  if (rel.startsWith('adapters/')) return 'adapters';
  if (rel.startsWith('services/')) return 'services';
  if (rel.startsWith('workers/')) return 'workers';
  if (rel.startsWith('core-client/')) return 'core-client';
  if (rel.startsWith('telemetry/')) return 'telemetry';
  if (rel.startsWith('test/')) return 'test';
  return 'other';
}

function targetLayer(file, imp) {
  if (imp.startsWith('.') || imp.startsWith('/')) {
    const resolved = path.resolve(path.dirname(file), imp);
    // Exact file or directory with index? We only need layer prefix.
    const rel = path.relative(MW, resolved);
    if (rel.startsWith('src/routes')) return 'routes';
    if (rel.startsWith('src/')) return 'src';
    if (rel.startsWith('adapters/')) return 'adapters';
    if (rel.startsWith('services/')) return 'services';
    if (rel.startsWith('workers/')) return 'workers';
    if (rel.startsWith('core-client/')) return 'core-client';
    if (rel.startsWith('telemetry/')) return 'telemetry';
    return 'other';
  }
  if (imp.includes('/services/') || imp.includes('/workers/') || imp.includes('/core-client/') || imp.includes('/telemetry/') || imp.includes('/adapters/')) {
    if (imp.includes('/services/')) return 'services';
    if (imp.includes('/workers/')) return 'workers';
    if (imp.includes('/core-client/')) return 'core-client';
    if (imp.includes('/telemetry/')) return 'telemetry';
    if (imp.includes('/adapters/')) return 'adapters';
  }
  return 'external';
}

const isCompositionRoot = (f) => path.basename(f) === 'server.js';
const isShim = (f, src) => {
  // Shims are single-line re-exports for backward compat (ADR-0006).
  const lines = stripComments(src).split('\n').map((l) => l.trim()).filter(Boolean);
  return lines.length === 1 && lines[0].startsWith('export * from');
};

for (const f of listJs(MW)) {
  const layer = layerOf(f);
  if (layer === 'test' || layer === 'other') continue;
  const rel = path.relative(ROOT, f);
  const src = readFileSync(f, 'utf8');
  if (isShim(f, src)) continue; // shims are allowed to point at canonical
  if (layer === 'src' && isCompositionRoot(f)) continue; // server.js wires all
  // Barrel files only re-export (routes/index.js). Allowlist their imports.
  if (path.basename(f) === 'index.js' && layer === 'routes') continue;
  for (const imp of importsOf(src)) {
    const target = targetLayer(f, imp);
    if (target === 'external' || target === 'other') continue;
    // routes: validation only (checked in purity too, kept here for graph)
    if (layer === 'routes') {
      if (target !== 'other' && imp !== '../validation.js') {
        fail(`${rel}: routes must only import ../validation.js (got '${imp}')`);
      }
      continue;
    }
    if (layer === 'src') {
      if (target === 'services' || target === 'workers') {
        fail(`${rel}: src must not import ${target} directly (use adapters; got '${imp}')`);
      }
      if (target === 'src' && imp.includes('/services/')) {
        fail(`${rel}: src must not reach services via src path ('${imp}')`);
      }
      continue;
    }
    if (layer === 'adapters') {
      if (target === 'src' && !imp.endsWith('/validation.js')) {
        fail(`${rel}: adapters must not import src (except validation.js; got '${imp}')`);
      }
      if (target === 'workers') {
        fail(`${rel}: adapters must not import workers ('${imp}')`);
      }
      continue;
    }
    if (layer === 'services') {
      if (target === 'src' || target === 'workers' || target === 'adapters') {
        fail(`${rel}: services must not import ${target} (got '${imp}')`);
      }
      continue;
    }
    if (layer === 'workers') {
      if (target === 'src') {
        fail(`${rel}: workers must not import src (use core-client/telemetry; got '${imp}')`);
      }
      continue;
    }
    if (layer === 'core-client') {
      if (target === 'src' || target === 'services' || target === 'workers' || target === 'adapters') {
        fail(`${rel}: core-client must not import ${target} (got '${imp}')`);
      }
      continue;
    }
    if (layer === 'telemetry') {
      if (target !== 'external' && target !== 'other' && target !== 'telemetry') {
        fail(`${rel}: telemetry must be a leaf (got '${imp}')`);
      }
      continue;
    }
  }
}

// Cycle check (cheap): core-client ↔ telemetry must be one-way (core-client → telemetry only).
{
  const teleFiles = listJs(path.join(MW, 'telemetry'));
  for (const f of teleFiles) {
    const src = readFileSync(f, 'utf8');
    for (const imp of importsOf(src)) {
      const t = targetLayer(f, imp);
      if (t === 'core-client' || t === 'src' || t === 'services' || t === 'workers' || t === 'adapters') {
        fail(`${path.relative(ROOT, f)}: telemetry must not import ${t} ('${imp}')`);
      }
    }
  }
}

if (failures.length) {
  console.error('DEPENDENCY GRAPH VIOLATIONS (ADR-0006):');
  for (const m of failures) console.error(`  ${m}`);
  console.error(`\n${failures.length} violation(s). One-way: src→adapters→services, leaves core-client/telemetry.`);
  process.exit(1);
}

console.log('OK: dependency graph holds (ADR-0006 one-way layering)');
