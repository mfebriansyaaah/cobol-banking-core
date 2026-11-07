// Per-route authentication guard.
//
// scripts/ci/sast.sh asks whether a *file* mentions tokenIdentity. That is
// enough to notice a module with no auth at all, but not enough to notice one
// endpoint in an otherwise guarded file losing its identity: the file still
// contains the string, so SAST stays green while that endpoint accepts
// unauthenticated callers.
//
// This walks each route object instead of the file. Every mutating method
// (POST/PUT/PATCH/DELETE) must carry tokenIdentity, unless the route is listed
// as intentionally public in tests/known_public_routes.txt.
//
// The baseline is a ratchet in both directions: an unguarded route that is not
// listed fails, and a listed route that is now guarded (or gone) also fails, so
// the file cannot accumulate stale exemptions.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { ownerFor } from './lib/route_owners.mjs';

const ROOT = path.resolve(process.argv[2] || '.');
const routesDir = path.join(ROOT, 'middleware', 'src', 'routes');
const baselinePath = path.join(ROOT, 'tests', 'known_public_routes.txt');
const MUTATING = new Set(['post', 'put', 'patch', 'delete']);

// Balanced-brace extraction that ignores braces inside string literals.
function routeObjects(source, file) {
  const found = [];
  for (let i = 0; i < source.length; i += 1) {
    if (source[i] !== '{') continue;
    if (!/^\s*method\s*:/.test(source.slice(i + 1, i + 40))) continue;

    let depth = 0;
    let quote = null;
    let j = i;
    for (; j < source.length; j += 1) {
      const ch = source[j];
      if (quote) {
        if (ch === quote && source[j - 1] !== '\\') quote = null;
        continue;
      }
      if (ch === "'" || ch === '"') {
        quote = ch;
        continue;
      }
      if (ch === '{') depth += 1;
      else if (ch === '}') {
        depth -= 1;
        if (depth === 0) break;
      }
    }

    const body = source.slice(i, j + 1);
    const method = body.match(/method\s*:\s*'([a-z]+)'/);
    const routePath = body.match(/path\s*:\s*'([^']+)'/);
    const action = body.match(/action\s*:\s*'([A-Z0-9_]+)'/);
    found.push({
      file,
      line: source.slice(0, i).split('\n').length,
      method: method ? method[1] : null,
      path: routePath ? routePath[1] : null,
      action: action ? action[1] : null,
      guarded: /tokenIdentity\s*:/.test(body),
    });
    i = j;
  }
  return found;
}

const sources = readdirSync(routesDir)
  .filter((f) => f.endsWith('.js') && f !== 'index.js')
  .sort()
  .map((f) => ({ file: f, source: readFileSync(path.join(routesDir, f), 'utf8') }));
sources.push({
  file: 'app.js',
  source: readFileSync(path.join(ROOT, 'middleware', 'src', 'app.js'), 'utf8'),
});

const routes = sources.flatMap((s) => routeObjects(s.source, s.file));
const unguarded = routes.filter((r) => MUTATING.has(r.method) && !r.guarded);

const baseline = new Set(
  (existsSync(baselinePath) ? readFileSync(baselinePath, 'utf8') : '')
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#')),
);

const key = (r) => `${r.method.toUpperCase()} ${r.path}`;
const foundKeys = new Set(unguarded.map(key));

const ownerless = routes.filter((r) => r.path && !ownerFor(r.path));

let failed = false;
if (ownerless.length) {
  failed = true;
  console.error('ROUTES WITHOUT AN OWNER (add the prefix to scripts/lib/route_owners.mjs):');
  for (const r of ownerless) {
    console.error(`  ${r.file}:${r.line}  ${key(r)}  (${r.action})`);
  }
}

const unlisted = unguarded.filter((r) => !baseline.has(key(r)));
const stale = [...baseline].filter((k) => !foundKeys.has(k));

if (unlisted.length) {
  failed = true;
  console.error('MUTATING ROUTES WITHOUT tokenIdentity:');
  for (const r of unlisted) {
    console.error(`  ${r.file}:${r.line}  ${key(r)}  (${r.action})`);
  }
  console.error('  Either add tokenIdentity or list the route in tests/known_public_routes.txt.');
}
if (stale.length) {
  failed = true;
  console.error('STALE PUBLIC-ROUTE EXEMPTIONS (now guarded or removed; delete the line):');
  for (const k of stale) console.error(`  ${k}`);
}
if (failed) {
  console.error(`\nbaseline: ${baselinePath}`);
  process.exit(1);
}

const mutating = routes.filter((r) => MUTATING.has(r.method)).length;
console.log(`OK: ${mutating} mutating route(s) are guarded, ${unguarded.length} known public exemption(s)`);
