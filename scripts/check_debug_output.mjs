// Debug-output gate (P0-04): COBOL must never emit DEBUG| protocol lines.
// Dead `MOVE "DEBUG|..."` writes are noise at best and a client-visible
// protocol leak at worst. The gateway only accepts SUCCESS|/ERROR|.
// Usage: node scripts/check_debug_output.mjs [root]
// Exit: 0 ok, 1 violation, 2 usage error.
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
for (const a of args) {
  if (a === '--help' || a === '-h') {
    console.log('usage: check_debug_output.mjs [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else root = a;
}
root = path.resolve(root);

const dirs = [path.join(root, 'cobol', 'src'), path.join(root, 'cobol', 'copy')];
const errors = [];
for (const dir of dirs) {
  if (!existsSync(dir)) continue;
  for (const f of readdirSync(dir)
    .filter((x) => x.endsWith('.cob') || x.endsWith('.cpy'))
    .sort()) {
    const src = readFileSync(path.join(dir, f), 'utf8');
    const hits = [...src.matchAll(/DEBUG\|/g)];
    if (hits.length > 0) {
      errors.push(`${f}: ${hits.length} DEBUG| occurrence(s) (remove debug writes; protocol is SUCCESS|/ERROR| only)`);
    }
  }
}

if (errors.length) {
  console.error('DEBUG-OUTPUT VIOLATIONS:');
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}
console.log('OK: no DEBUG| output in COBOL sources');
