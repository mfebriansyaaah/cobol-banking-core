import { readdirSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { parseDispatchTable } from './lib/dispatch_table.mjs';

const ROOT = path.resolve(process.argv[2] || '.');
let failures = 0;
const fail = (msg) => {
  console.error(`FAIL: ${msg}`);
  failures += 1;
};
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
// An empty dispatch table used to make this whole section a no-op, which is
// how main_logic.cob's table refactor shipped with a blank manifest. The
// manifest is now compared *exactly* against what the COBOL source declares.
const mainLogicPath = path.join(cobolDir, 'main_logic.cob');
const mainLogic = readFileSync(mainLogicPath, 'utf8');
const { entries: actualDispatch, problems } = parseDispatchTable(mainLogic);
for (const p of problems) fail(p);

if (actualDispatch.length === 0) {
  fail('no dispatch entries found in main_logic.cob (dispatcher format changed?)');
} else if (!Array.isArray(manifest.dispatch) || manifest.dispatch.length === 0) {
  fail('manifest has no dispatch entries (run scripts/generate_manifest.mjs)');
} else {
  const declared = manifest.dispatch.map((d) => ({
    prefixLen: d.prefixLen,
    prefix: d.prefix,
    program: d.program,
  }));
  if (JSON.stringify(declared) !== JSON.stringify(actualDispatch)) {
    const missing = actualDispatch.filter(
      (d) => !declared.some((x) => x.prefix === d.prefix && x.program === d.program && x.prefixLen === d.prefixLen),
    );
    const extra = declared.filter(
      (d) =>
        !actualDispatch.some((x) => x.prefix === d.prefix && x.program === d.program && x.prefixLen === d.prefixLen),
    );
    if (missing.length) fail(`dispatch entries missing from manifest: ${missing.map((d) => d.prefix).join(', ')}`);
    if (extra.length)
      fail(`manifest lists dispatch entries not in main_logic.cob: ${extra.map((d) => d.prefix).join(', ')}`);
    if (!missing.length && !extra.length) fail('dispatch entries are out of order; regenerate the manifest');
  } else {
    ok(`${actualDispatch.length} dispatch entries match main_logic.cob`);
  }
}

for (const d of actualDispatch) {
  const source = `${d.program}.cob`;
  if (!existsSync(path.join(cobolDir, source))) fail(`dispatch program has no cobol source: ${source}`);
}

if (failures > 0) {
  console.error(`\n${failures} manifest check(s) failed`);
  process.exit(1);
}
console.log('\nALL MANIFEST CHECKS PASSED');
