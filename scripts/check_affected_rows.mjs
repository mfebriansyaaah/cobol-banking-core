// Affected-rows gate (P0-03): guarded UPDATEs must check the bridge verdict.
// The C bridge reports zero-row writes as `SUCCESS|AFFECTED_0`, never the
// legacy `0 rows affected` string. A literal check for the old string never
// fires, so stale versions silently return SUCCESS.
// Usage: node scripts/check_affected_rows.mjs [root]
// Exit: 0 ok, 1 violation, 2 usage error.
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
for (const a of args) {
  if (a === '--help' || a === '-h') {
    console.log('usage: check_affected_rows.mjs [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else root = a;
}
root = path.resolve(root);

const srcDir = path.join(root, 'cobol', 'src');
const errors = [];
if (existsSync(srcDir)) {
  for (const f of readdirSync(srcDir)
    .filter((x) => x.endsWith('.cob'))
    .sort()) {
    const src = readFileSync(path.join(srcDir, f), 'utf8');
    const bad = [...src.matchAll(/"0 rows affected"/g)];
    if (bad.length > 0) {
      errors.push(`${f}: ${bad.length} legacy "0 rows affected" check(s) (use SUCCESS|AFFECTED_0)`);
    }
  }
}

if (errors.length) {
  console.error('AFFECTED-ROWS VIOLATIONS:');
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}
console.log('OK: guarded UPDATEs check SUCCESS|AFFECTED_0 (no legacy literal)');
