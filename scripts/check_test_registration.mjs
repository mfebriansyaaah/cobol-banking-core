// Test-registration guard (maint-02): every gateway test file must belong
// to at least one group in middleware/scripts/test-files.mjs. A new
// *.test.js that nobody runs must fail this gate instead of silently never
// executing (the failure mode the registry was built to prevent).
//
// Usage: node scripts/check_test_registration.mjs [root]
// Exit: 0 ok, 1 violation, 2 usage error.
import { readdirSync, existsSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { GROUPS } from '../middleware/scripts/test-files.mjs';

export function listTestFiles(testDir) {
  const out = [];
  const walk = (dir, prefix) => {
    if (!existsSync(dir)) return;
    for (const e of readdirSync(dir, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
      const rel = prefix ? `${prefix}/${e.name}` : e.name;
      if (e.isDirectory()) walk(path.join(dir, e.name), rel);
      else if (e.name.endsWith('.test.js')) out.push(`test/${rel}`);
    }
  };
  walk(testDir, '');
  return out;
}

export function checkRegistration(files, groups) {
  const covered = new Set(Object.values(groups).flat());
  return files.filter((f) => !covered.has(f)).sort();
}

const args = process.argv.slice(2);
let root = '.';
for (const a of args) {
  if (a === '--help' || a === '-h') {
    console.log('usage: check_test_registration.mjs [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const files = listTestFiles(path.join(path.resolve(root), 'middleware', 'test'));
  const missing = checkRegistration(files, GROUPS);
  if (missing.length) {
    console.error('UNREGISTERED GATEWAY TEST FILES (add to a group in middleware/scripts/test-files.mjs):');
    for (const f of missing) console.error(`  ${f}`);
    process.exit(1);
  }
  console.log(`OK: all ${files.length} gateway test files registered in a group`);
}
