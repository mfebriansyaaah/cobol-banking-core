// Route barrel renderer (PR-052): middleware/src/routes/index.js generated
// from routes/*.js exports. Spread order follows the committed file (new
// files append sorted); every export must be spread exactly once — the
// forgotten-spread class that once dead-registered a route file.
// Usage: node scripts/render_route_barrel.mjs [--write]
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';

const ROOT = new URL('..', import.meta.url).pathname.replace(/\/$/, '');
const WRITE = process.argv.includes('--write');
const OUT = `${ROOT}/middleware/src/routes/index.js`;

const files = readdirSync(`${ROOT}/middleware/src/routes`)
  .filter((f) => f.endsWith('.js') && f !== 'index.js')
  .sort();
const exportsByFile = new Map();
for (const f of files) {
  const src = readFileSync(`${ROOT}/middleware/src/routes/${f}`, 'utf8');
  const names = [...src.matchAll(/export const (\w+_ROUTES) = \[/g)].map((m) => m[1]);
  if (!names.length) {
    console.error(`route file without *_ROUTES export: ${f}`);
    process.exit(1);
  }
  exportsByFile.set(f, names);
}

const current = readFileSync(OUT, 'utf8');
const ordered = [];
for (const m of current.matchAll(/\.\.\.(\w+_ROUTES),?/g)) ordered.push(m[1]);
const known = new Set(ordered);
const missing = [];
for (const names of exportsByFile.values()) {
  for (const n of names) if (!known.has(n)) missing.push(n);
}
missing.sort();
const stale = ordered.filter((n) => ![...exportsByFile.values()].flat().includes(n));
if (stale.length) {
  console.error(`stale spreads (no export found): ${stale.join(', ')}`);
  process.exit(1);
}
const final = [...ordered, ...missing];
const fileOf = new Map();
for (const [f, names] of exportsByFile) for (const n of names) fileOf.set(n, f);

const lines = [];
for (const n of final) lines.push(`import { ${n} } from './${fileOf.get(n)}';`);
lines.push('', 'export const ALL_ROUTES = [');
for (const n of final) lines.push(`  ...${n},`);
lines.push('];', '');
const rendered = `${lines.join('\n')}`;

if (!WRITE) {
  if (current !== rendered) {
    console.error('route barrel drifted: run scripts/render_route_barrel.mjs --write and review the diff');
    process.exit(1);
  }
  console.log(`OK: route barrel in sync (${final.length} spreads)`);
} else {
  writeFileSync(OUT, rendered);
  console.log(`wrote ${OUT}: ${final.length} spreads`);
}
