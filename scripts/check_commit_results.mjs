// Commit-result gate (P0-02): every SQL_COMMIT must be fail-closed.
// Allowed shapes:
//   - cobol/copy/common_txn.cpy and common_commit.cpy: CALL + GET_RESULT + SUCCESS|COMMIT check.
//   - cobol/src/*.cob: PERFORM COMMIT-CHECKED (shared helper in common_commit.cpy).
// A bare `CALL "SQL_COMMIT"` in src is a regression (false SUCCESS on commit failure).
// Usage: node scripts/check_commit_results.mjs [root]
// Exit: 0 ok, 1 violation, 2 usage error.
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
for (const a of args) {
  if (a === '--help' || a === '-h') {
    console.log('usage: check_commit_results.mjs [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else root = a;
}
root = path.resolve(root);

const srcDir = path.join(root, 'cobol', 'src');
const copyDir = path.join(root, 'cobol', 'copy');
const errors = [];

// 1. No bare CALL in src: every commit must go through the helper.
if (existsSync(srcDir)) {
  for (const f of readdirSync(srcDir)
    .filter((x) => x.endsWith('.cob'))
    .sort()) {
    const src = readFileSync(path.join(srcDir, f), 'utf8');
    const bare = [...src.matchAll(/CALL\s+"SQL_COMMIT"/g)];
    if (bare.length > 0) {
      errors.push(`${f}: ${bare.length} bare CALL "SQL_COMMIT" (use PERFORM COMMIT-CHECKED)`);
    }
    // Helper must be reachable: files that PERFORM it must COPY the copybook.
    if (src.includes('PERFORM COMMIT-CHECKED') && !src.includes('COPY "common_commit.cpy"')) {
      errors.push(`${f}: PERFORM COMMIT-CHECKED without COPY "common_commit.cpy"`);
    }
  }
}

// 2. Copybook allowlist: only the two finalizers may CALL directly, and both must check.
for (const f of ['common_txn.cpy', 'common_commit.cpy']) {
  const p = path.join(copyDir, f);
  if (!existsSync(p)) {
    errors.push(`missing required copybook: cobol/copy/${f}`);
    continue;
  }
  const src = readFileSync(p, 'utf8');
  if (!src.includes('CALL "SQL_COMMIT"')) {
    errors.push(`cobol/copy/${f}: no CALL "SQL_COMMIT" (helper lost its commit?)`);
  }
  if (!src.includes('GET_RESULT') || !src.includes('SUCCESS|COMMIT')) {
    errors.push(`cobol/copy/${f}: commit result not checked (GET_RESULT + SUCCESS|COMMIT required)`);
  }
}

// 3. No other copybook may CALL commit directly.
if (existsSync(copyDir)) {
  for (const f of readdirSync(copyDir)
    .filter((x) => x.endsWith('.cpy'))
    .sort()) {
    if (f === 'common_txn.cpy' || f === 'common_commit.cpy') continue;
    const src = readFileSync(path.join(copyDir, f), 'utf8');
    if (src.includes('CALL "SQL_COMMIT"')) {
      errors.push(`cobol/copy/${f}: direct CALL "SQL_COMMIT" outside allowlist (use PERFORM COMMIT-CHECKED)`);
    }
  }
}

if (errors.length) {
  console.error('COMMIT-RESULT VIOLATIONS:');
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}
console.log('OK: commit results are fail-closed (src uses PERFORM COMMIT-CHECKED; copybooks check SUCCESS|COMMIT)');
