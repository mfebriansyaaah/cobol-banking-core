import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');

// COBOL modules (excluding the dispatcher itself).
const cobolDir = path.join(ROOT, 'cobol', 'src');
const cobolModules = readdirSync(cobolDir)
  .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob')
  .sort()
  .map((source) => ({ source }));

// Gateway route modules (excluding the barrel).
const routesDir = path.join(ROOT, 'middleware', 'src', 'routes');
const gatewayRoutes = readdirSync(routesDir)
  .filter((f) => f.endsWith('.js') && f !== 'index.js')
  .sort();

// Dispatch entries parsed from main_logic.cob.
const mainLogic = readFileSync(path.join(cobolDir, 'main_logic.cob'), 'utf8');
const dispatch = [];
const re = /IF CMD-ACTION\(1:(\d+)\) = "([^"]+)"[\s\S]*?CALL "([^"]+)"/g;
let m;
while ((m = re.exec(mainLogic)) !== null) {
  dispatch.push({ prefixLen: Number(m[1]), prefix: m[2], program: m[3] });
}
// Deduplicate (some prefixes map to same program; keep first occurrence).
const seen = new Set();
const uniqueDispatch = [];
for (const d of dispatch) {
  const key = `${d.prefix}|${d.program}`;
  if (seen.has(key)) continue;
  seen.add(key);
  uniqueDispatch.push(d);
}

const manifest = {
  generatedAt: new Date().toISOString(),
  cobolModules,
  gatewayRoutes,
  dispatch: uniqueDispatch,
};

writeFileSync(path.join(ROOT, 'manifest', 'modules.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`wrote manifest/modules.json: ${cobolModules.length} cobol modules, ${gatewayRoutes.length} route files, ${uniqueDispatch.length} dispatch entries`);
