import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { loadDispatchSource } from './lib/dispatch_table.mjs';

const ROOT = path.resolve(process.argv[2] || '.');

const mainLogic = loadDispatchSource(ROOT);
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

// The dispatch loop stops at DISPATCH-COUNT, so entries past that number are
// unreachable even though they are present in the table. Wave7 appended three
// domains (CRM_/VDM_/OSC_) but left the count at 327: the routes existed, the
// manifest matched, and every action still returned ERROR|INVALID_ACTION.
const slots = [...mainLogic.matchAll(/D-PREFIX\((\d+)\)/g)].map((x) => Number(x[1]));
const maxSlot = slots.length ? Math.max(...slots) : 0;
const countMatch = mainLogic.match(/MOVE\s+(\d+)\s+TO\s+DISPATCH-COUNT/);
if (!countMatch) {
  console.error('FAIL: main_logic.cob has no "MOVE n TO DISPATCH-COUNT"');
  process.exit(1);
}
const dispatchCount = Number(countMatch[1]);
if (dispatchCount !== maxSlot) {
  console.error(`FAIL: DISPATCH-COUNT is ${dispatchCount} but the highest D-PREFIX slot is ${maxSlot}`);
  console.error('Slots above the count are never scanned; every action for them returns INVALID_ACTION.');
  process.exit(1);
}

console.log(
  `OK: ${actions.length} gateway actions map to ${dispatchPrefixes.size} dispatch prefixes (count ${dispatchCount})`,
);
