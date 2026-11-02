import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { parseDispatchTable } from './lib/dispatch_table.mjs';

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

// Dispatch entries parsed from the table-driven dispatcher in main_logic.cob.
// The parser is shared with check_manifest.mjs (scripts/lib/dispatch_table.mjs)
// so the two can never disagree about the table format again.
const mainLogic = readFileSync(path.join(cobolDir, 'main_logic.cob'), 'utf8');
const { entries: uniqueDispatch, problems } = parseDispatchTable(mainLogic);
if (problems.length > 0) {
  for (const p of problems) console.error(`FAIL: ${p}`);
  console.error('\nrefusing to write a manifest from an inconsistent dispatch table');
  process.exit(1);
}
if (uniqueDispatch.length === 0) {
  console.error('FAIL: no dispatch entries found in main_logic.cob (unsupported table format)');
  process.exit(1);
}

const manifest = {
  generatedAt: new Date().toISOString(),
  cobolModules,
  gatewayRoutes,
  dispatch: uniqueDispatch,
};

writeFileSync(path.join(ROOT, 'manifest', 'modules.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(
  `wrote manifest/modules.json: ${cobolModules.length} cobol modules, ${gatewayRoutes.length} route files, ${uniqueDispatch.length} dispatch entries`,
);
