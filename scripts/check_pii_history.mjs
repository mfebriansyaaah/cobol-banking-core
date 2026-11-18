// PII history-worktree gate (P1-12): personal addresses from git history
// must never appear in tracked file contents.
//
// Git history legitimately contains author/committer personal addresses
// (see docs/DATASET_CARD.md PII status); dataset exports stay safe because
// scripts/export_dataset.sh ships `git archive` output (no .git, no author
// metadata), and history consumers must use the sanitized mirror from
// scripts/sanitize_dataset_history.sh. This gate locks the remaining half:
// no history address may leak into a tracked file, where `git archive`
// WOULD carry it into every export profile.
//
// Excluded: *@users.noreply.github.com (sanitized/anonymous) and empty
// identities. Only tracked files are scanned (`git grep`, so gitignored
// local files like tests/.dbenv can never trip it).
//
// Usage: node scripts/check_pii_history.mjs [root]
// Exit: 0 ok, 1 leak found, 2 usage error.
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
for (const a of args) {
  if (a === '--help' || a === '-h') {
    console.log('usage: check_pii_history.mjs [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else root = a;
}
root = path.resolve(root);

function git(args, input = undefined) {
  return execFileSync('git', args, {
    cwd: root,
    encoding: 'utf8',
    input,
    stdio: ['pipe', 'pipe', 'pipe'],
    timeout: 60000,
  });
}

let log;
try {
  log = git(['log', '--all', '--format=%ae%n%ce']);
} catch (e) {
  console.error(`FAIL: cannot read git history: ${e.message}`);
  process.exit(2);
}
const addresses = [
  ...new Set(
    log
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean),
  ),
].filter((e) => !e.endsWith('@users.noreply.github.com'));
if (addresses.length === 0) {
  console.log('OK: no personal addresses in git history (nothing to leak)');
  process.exit(0);
}

const leaks = [];
for (const addr of addresses) {
  let out;
  try {
    out = git(['grep', '-lF', '--', addr, '--', '.']);
  } catch (e) {
    // git grep exits 1 when nothing matches — that is the good case.
    if (e && e.status === 1) continue;
    console.error(`FAIL: git grep failed for ${addr}: ${e.message}`);
    process.exit(2);
  }
  const files = out
    .split('\n')
    .map((s) => s.trim())
    .filter(Boolean);
  if (files.length > 0) leaks.push({ addr, files });
}

if (leaks.length > 0) {
  console.error('PII LEAK VIOLATIONS (history address in tracked files):');
  for (const { addr, files } of leaks) {
    console.error(`  ${addr}:`);
    for (const f of files) console.error(`    ${f}`);
  }
  process.exit(1);
}
console.log(`OK: ${addresses.length} history address(es), none in tracked files`);
