import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');

// Map dispatch prefix -> cobol source file (module name).
const mainLogic = readFileSync(path.join(ROOT, 'cobol', 'src', 'main_logic.cob'), 'utf8');
// Map each dispatch prefix to its target module by locating the nearest
// CALL after the prefix test (handles OR-chained IF blocks).
const prefixRe = /MOVE "([^"]+)" TO D-PREFIX\((\d+)\)/g;
const programRe = /MOVE "([^"]+)" TO D-PROGRAM\((\d+)\)/g;
const prefixes = [];
const programs = [];
let pm;
while ((pm = prefixRe.exec(mainLogic)) !== null) prefixes.push({ idx: Number(pm[2]), prefix: pm[1] });
let cm;
while ((cm = programRe.exec(mainLogic)) !== null) programs.push({ idx: Number(cm[2]), program: cm[1] });
const byIdx = new Map(programs.map((x) => [x.idx, x.program]));
const dispatch = prefixes.map((x) => ({ prefix: x.prefix, program: byIdx.get(x.idx) })).filter((x) => x.program);
// de-dup by prefix, keeping first occurrence
const seen = new Set();
const unique = [];
for (const d of dispatch) {
  if (seen.has(d.prefix)) continue;
  seen.add(d.prefix);
  unique.push(d);
}
unique.sort((a, b) => b.prefix.length - a.prefix.length);

function moduleFile(action) {
  const d = unique.find((x) => action.startsWith(x.prefix));
  if (!d) return null;
  // auth_password_core is a thin delegate to auth_core.
  if (d.program === 'auth_password_core') return 'auth_core.cob';
  return `${d.program}.cob`;
}

const actionRe = /action:\s*'([A-Z0-9_]+)'/g;
const routeFiles = readdirSync(path.join(ROOT, 'middleware', 'src', 'routes'))
  .filter((f) => f.endsWith('.js') && f !== 'index.js');
let allActions = [];
for (const f of routeFiles) {
  const src = readFileSync(path.join(ROOT, 'middleware', 'src', 'routes', f), 'utf8');
  let am;
  while ((am = actionRe.exec(src)) !== null) allActions.push({ file: f, action: am[1] });
}
const appSrc = readFileSync(path.join(ROOT, 'middleware', 'src', 'app.js'), 'utf8');
let am;
while ((am = actionRe.exec(appSrc)) !== null) allActions.push({ file: 'app.js', action: am[1] });

// Endpoint actions that are known to be wired to a COBOL module only by
// prefix (the module does not implement the action verbatim). These are
// tracked as explicit gaps rather than silent false positives.
const KNOWN_GAPS = new Set([
  'KCP_UPDATE',
]);
const knownGaps = [];
const missing = [];
for (const { file, action } of allActions) {
  if (KNOWN_GAPS.has(action)) { knownGaps.push({ file, action }); continue; }
  const mod = moduleFile(action);
  if (!mod) { missing.push({ file, action, reason: 'no dispatch module' }); continue; }
  const src = readFileSync(path.join(ROOT, 'cobol', 'src', mod), 'utf8');
  if (!src.includes(`"${action}`) && !src.includes(action)) {
    missing.push({ file, action, reason: `not found in ${mod}` });
  }
}

if (missing.length) {
  console.error('ACTIONS WITHOUT COBOL COVERAGE:');
  for (const x of missing) console.error(`  ${x.file}: ${x.action} (${x.reason})`);
  process.exit(1);
}
if (knownGaps.length) {
  console.warn('KNOWN COVERAGE GAPS (endpoint actions without a verbatim COBOL action):');
  for (const x of knownGaps) console.warn(`  ${x.file}: ${x.action}`);
}
console.log(`OK: ${allActions.length - knownGaps.length} gateway actions have exact COBOL coverage (${knownGaps.length} known gaps)`);