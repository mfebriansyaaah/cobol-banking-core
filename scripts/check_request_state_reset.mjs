// Request-state reset gate (audit C-01): WORKING-STORAGE persists across
// --serve calls, so every module that uses WS-ERR must reset it at
// MAIN-LOGIC entry. Otherwise a stale error leaks into the next request.
// Usage: node scripts/check_request_state_reset.mjs [root]
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const dir = path.join(ROOT, 'cobol', 'src');
const failures = [];
let checked = 0;

for (const f of readdirSync(dir)
  .filter((x) => x.endsWith('.cob'))
  .sort()) {
  const src = readFileSync(path.join(dir, f), 'utf8');
  if (!src.includes('WS-ERR')) continue;
  checked += 1;
  const m = /^(\s*)MAIN-LOGIC\.\s*$/m.exec(src);
  if (!m) {
    failures.push(`${f}: MAIN-LOGIC label not found`);
    continue;
  }
  const after = src
    .slice(m.index + m[0].length)
    .split('\n')
    .slice(1, 11)
    .join('\n');
  if (!after.includes('MOVE SPACES TO WS-ERR')) {
    failures.push(`${f}: WS-ERR not reset within 10 lines after MAIN-LOGIC`);
  }
}

if (failures.length) {
  for (const f of failures) console.error(`FAIL: ${f}`);
  process.exit(1);
}
console.log(`OK: ${checked} modules reset WS-ERR at entry`);
