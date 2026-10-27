import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');

const mainLogic = readFileSync(path.join(ROOT, 'cobol', 'src', 'main_logic.cob'), 'utf8');
const dispatchPrefixes = new Set();
const re = /MOVE "([^"]+)" TO D-PREFIX\(\d+\)/g;
let m;
while ((m = re.exec(mainLogic)) !== null) dispatchPrefixes.add(m[1]);

const routesDir = path.join(ROOT, 'middleware', 'src', 'routes');
const actionRe = /action:\s*'([A-Z0-9_]+)'/g;
const actions = [];
for (const f of readdirSync(routesDir).filter((x) => x.endsWith('.js') && x !== 'index.js')) {
  const src = readFileSync(path.join(routesDir, f), 'utf8');
  let am;
  while ((am = actionRe.exec(src)) !== null) actions.push({ file: f, action: am[1] });
}
// app.js also defines routes inline
const appSrc = readFileSync(path.join(ROOT, 'middleware', 'src', 'app.js'), 'utf8');
let am;
while ((am = actionRe.exec(appSrc)) !== null) actions.push({ file: 'app.js', action: am[1] });

const missing = [];
for (const { file, action } of actions) {
  const ok = [...dispatchPrefixes].some((p) => action.startsWith(p));
  if (!ok) missing.push({ file, action });
}

if (missing.length) {
  console.error('MISSING DISPATCH PREFIX for gateway actions:');
  for (const x of missing) console.error(`  ${x.file}: ${x.action}`);
  process.exit(1);
}
console.log(`OK: ${actions.length} gateway actions map to ${dispatchPrefixes.size} dispatch prefixes`);