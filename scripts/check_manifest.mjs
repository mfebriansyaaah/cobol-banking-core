import { readdirSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
let failures = 0;
const fail = (msg) => { console.error(`FAIL: ${msg}`); failures += 1; };
const ok = (msg) => console.log(`OK: ${msg}`);

const manifestPath = path.join(ROOT, 'manifest', 'modules.json');
if (!existsSync(manifestPath)) {
  console.error('FAIL: manifest/modules.json missing (run scripts/generate_manifest.mjs)');
  process.exit(1);
}
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));

// --- COBOL modules ---------------------------------------------------------
const cobolDir = path.join(ROOT, 'cobol', 'src');
const actualCobol = readdirSync(cobolDir)
  .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob')
  .sort();
const manifestCobol = (manifest.cobolModules || []).map((e) => e.source).sort();

if (JSON.stringify(actualCobol) !== JSON.stringify(manifestCobol)) {
  const missing = actualCobol.filter((f) => !manifestCobol.includes(f));
  const extra = manifestCobol.filter((f) => !actualCobol.includes(f));
  if (missing.length) fail(`cobol modules missing from manifest: ${missing.join(', ')}`);
  if (extra.length) fail(`manifest lists cobol modules not present: ${extra.join(', ')}`);
} else {
  ok(`${actualCobol.length} cobol modules match manifest`);
}

// build.sh must compile exactly the manifest cobol modules + main_logic.cob.
const buildSh = readFileSync(path.join(ROOT, 'build.sh'), 'utf8');
const buildSources = [...buildSh.matchAll(/cobol\/src\/([A-Za-z0-9_]+\.cob)/g)].map((m) => m[1]);
const expectedBuild = [...manifestCobol, 'main_logic.cob'].sort();
const actualBuild = [...new Set(buildSources)].sort();
if (JSON.stringify(actualBuild) !== JSON.stringify(expectedBuild)) {
  const missing = expectedBuild.filter((f) => !actualBuild.includes(f));
  const extra = actualBuild.filter((f) => !expectedBuild.includes(f));
  if (missing.length) fail(`build.sh missing cobol sources: ${missing.join(', ')}`);
  if (extra.length) fail(`build.sh lists cobol sources not in manifest: ${extra.join(', ')}`);
} else {
  ok(`build.sh includes all ${expectedBuild.length} cobol sources`);
}

// --- Gateway route modules -------------------------------------------------
const routesDir = path.join(ROOT, 'middleware', 'src', 'routes');
const actualRoutes = readdirSync(routesDir)
  .filter((f) => f.endsWith('.js') && f !== 'index.js')
  .sort();
const manifestRoutes = [...(manifest.gatewayRoutes || [])].sort();
if (JSON.stringify(actualRoutes) !== JSON.stringify(manifestRoutes)) {
  const missing = actualRoutes.filter((f) => !manifestRoutes.includes(f));
  const extra = manifestRoutes.filter((f) => !actualRoutes.includes(f));
  if (missing.length) fail(`route files missing from manifest: ${missing.join(', ')}`);
  if (extra.length) fail(`manifest lists route files not present: ${extra.join(', ')}`);
} else {
  ok(`${actualRoutes.length} gateway route files match manifest`);
}

const indexJs = readFileSync(path.join(routesDir, 'index.js'), 'utf8');
const importedRoutes = [...indexJs.matchAll(/from '\.\/([A-Za-z0-9_-]+\.js)'/g)].map((m) => m[1]).sort();
if (JSON.stringify(importedRoutes) !== JSON.stringify(manifestRoutes)) {
  const missing = manifestRoutes.filter((f) => !importedRoutes.includes(f));
  const extra = importedRoutes.filter((f) => !manifestRoutes.includes(f));
  if (missing.length) fail(`index.js does not import: ${missing.join(', ')}`);
  if (extra.length) fail(`index.js imports routes not in manifest: ${extra.join(', ')}`);
} else {
  ok(`index.js imports all ${importedRoutes.length} route files`);
}

// --- Dispatch entries ------------------------------------------------------
const mainLogicPath = path.join(cobolDir, 'main_logic.cob');
const mainLogic = readFileSync(mainLogicPath, 'utf8');
for (const d of manifest.dispatch || []) {
  const needleIf = `CMD-ACTION(1:${d.prefixLen}) = "${d.prefix}"`;
  const needleCall = `CALL "${d.program}"`;
  if (!mainLogic.includes(needleIf)) fail(`dispatch entry not found in main_logic.cob: ${needleIf}`);
  if (!mainLogic.includes(needleCall)) fail(`dispatch program not called in main_logic.cob: ${needleCall}`);
  const source = `${d.program}.cob`;
  if (!existsSync(path.join(cobolDir, source))) fail(`dispatch program has no cobol source: ${source}`);
}
if ((manifest.dispatch || []).length > 0 && failures === 0) {
  ok(`${(manifest.dispatch || []).length} dispatch entries verified against main_logic.cob`);
}

if (failures > 0) {
  console.error(`\n${failures} manifest check(s) failed`);
  process.exit(1);
}
console.log('\nALL MANIFEST CHECKS PASSED');
