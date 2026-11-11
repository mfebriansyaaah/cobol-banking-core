// PR-size policy guard (maint-00): the risk-based sizing rule must stay
// in the policy docs. Fails when the old fixed ceiling returns or the
// 1.500-line preference / exception rule / PR template fields go missing.
//
// Checked files:
//   docs/BRANCHING.md — no "3500"/"3,500" ceiling; contains "1.500",
//     "exception", and "No fixed line ceiling".
//   docs/GOVERNANCE.md — contains "1.500"; no "under 500"/"ceiling 3500"/"3500".
//   CONTRIBUTING.md — contains "1.500"; no "3500".
//   .github/pull_request_template.md — contains "Size tier", "Total diff",
//     "Semantic diff", "Exception".
//
// Usage: node scripts/check_pr_size_policy.mjs [root]
// Exit: 0 ok, 1 violation, 2 usage error.
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function checkPolicy(rootDir = '.') {
  const errors = [];
  const read = (rel) => {
    const full = path.join(rootDir, rel);
    if (!existsSync(full)) {
      errors.push(`missing required file: ${rel}`);
      return null;
    }
    return readFileSync(full, 'utf8');
  };

  const branching = read('docs/BRANCHING.md');
  if (branching !== null) {
    if (/3500|3,500/.test(branching)) {
      errors.push('docs/BRANCHING.md: fixed 3500-line ceiling returned (use the 1.500 preference + exception rule)');
    }
    if (!branching.includes('1.500')) {
      errors.push('docs/BRANCHING.md: missing 1.500-line preference');
    }
    if (!/exception/i.test(branching)) {
      errors.push('docs/BRANCHING.md: missing exception rule');
    }
    if (!/no fixed line ceiling/i.test(branching)) {
      errors.push('docs/BRANCHING.md: missing "No fixed line ceiling" statement');
    }
  }

  const governance = read('docs/GOVERNANCE.md');
  if (governance !== null) {
    if (/under 500|ceiling 3500|3500/.test(governance)) {
      errors.push('docs/GOVERNANCE.md: old 500/3500 sizing rule returned (use the 1.500 preference + exception rule)');
    }
    if (!governance.includes('1.500')) {
      errors.push('docs/GOVERNANCE.md: missing 1.500-line preference');
    }
  }

  const contributing = read('CONTRIBUTING.md');
  if (contributing !== null) {
    if (/3500/.test(contributing)) {
      errors.push('CONTRIBUTING.md: old 3500-line ceiling returned (use the 1.500 preference + exception rule)');
    }
    if (!contributing.includes('1.500')) {
      errors.push('CONTRIBUTING.md: missing 1.500-line preference');
    }
  }

  const template = read('.github/pull_request_template.md');
  if (template !== null) {
    for (const field of ['Size tier', 'Total diff', 'Semantic diff', 'Exception']) {
      if (!template.includes(field)) {
        errors.push(`.github/pull_request_template.md: missing field "${field}"`);
      }
    }
  }

  return errors;
}

const args = process.argv.slice(2);
let root = '.';
for (const a of args) {
  if (a === '--help' || a === '-h') {
    console.log('usage: check_pr_size_policy.mjs [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const errors = checkPolicy(path.resolve(root));
  if (errors.length) {
    console.error('PR-SIZE POLICY VIOLATIONS:');
    for (const e of errors) console.error(`  ${e}`);
    process.exit(1);
  }
  console.log('OK: PR-size policy holds (1.500 preference + exception, no fixed ceiling)');
}
