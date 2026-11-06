// Every COBOL action referenced by a table case must be reachable through the
// dispatcher. A case that names an action no prefix matches does not test the
// core — it tests that the dispatcher rejects it, which is why three suites
// (ntf/rsc/sla) were "failing" with ERROR|INVALID_ACTION while looking like
// ordinary input-validation cases.
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { parseDispatchTable, loadDispatchSource } from './lib/dispatch_table.mjs';

const ROOT = path.resolve(process.argv[2] || '.');
const casesDir = path.join(ROOT, 'tests', 'cobol', 'cases');

const mainLogic = loadDispatchSource(ROOT);
const { entries } = parseDispatchTable(mainLogic);

// COBOL compares CMD-ACTION(1:LEN) with D-PREFIX(1:LEN) on space-padded
// PIC X(20) fields, so pad before comparing instead of using startsWith.
const WIDTH = 20;
function matches(prefix, len, action) {
  return action.padEnd(WIDTH).slice(0, len) === prefix.padEnd(WIDTH).slice(0, len);
}

const missing = [];
let checked = 0;
for (const file of readdirSync(casesDir)
  .filter((f) => f.endsWith('.cases'))
  .sort()) {
  const lines = readFileSync(path.join(casesDir, file), 'utf8').split('\n');
  lines.forEach((line, idx) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return;
    const parts = trimmed.split('@@');
    if (parts.length < 3) {
      missing.push({ file, line: idx + 1, action: '(malformed case)', reason: 'expected name@@expected@@input' });
      return;
    }
    const action = parts[2].split('|')[0].trim();
    // core.cases intentionally exercises the dispatcher's own rejection paths
    // (empty action / unknown action), so those are allowed to be unreachable.
    const expectsRejection = /(INVALID_ACTION|MISSING_ACTION)/.test(parts[1]);
    if (!action) {
      if (expectsRejection) return;
      missing.push({ file, line: idx + 1, action: '(empty)', reason: 'no action in input' });
      return;
    }
    checked += 1;
    if (!entries.some((e) => matches(e.prefix, e.prefixLen, action))) {
      if (expectsRejection) return;
      missing.push({ file, line: idx + 1, action, reason: 'no dispatch prefix matches' });
    }
  });
}

if (missing.length) {
  console.error('TABLE CASES THAT CANNOT REACH A MODULE:');
  for (const m of missing) console.error(`  ${m.file}:${m.line}  ${m.action}  (${m.reason})`);
  console.error(`\n${missing.length} of ${checked} case(s) are undispatchable`);
  process.exit(1);
}

console.log(`OK: ${checked} table case action(s) are dispatchable`);
