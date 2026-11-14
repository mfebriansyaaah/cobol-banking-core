// Transaction-ownership gate (ADR-0006): one transaction, one owner.
//   - No orphan COMMIT/ROLLBACK: a file that closes a transaction must open
//     one (SQL_BEGIN). An orphan close returns ERROR|NO_TRANSACTION and
//     implies atomicity that does not exist (the eod_jobs_core bug class:
//     START/FINISH ran autocommit while FINISH issued COMMIT/ROLLBACK).
//   - A file that opens (SQL_BEGIN) must close on both paths (COMMIT and
//     ROLLBACK present); otherwise a failure path leaks an open transaction
//     onto the pooled connection.
// Autocommit single-statement files (0/0/0) are allowed.
// COPY-expanded (DRY-00B): counts see through COPY includes, so moving a
// transaction statement into a copybook cannot hide it from this gate.
// Usage: node scripts/check_transaction_ownership.mjs [root]
import { readdirSync } from 'node:fs';
import path from 'node:path';
import { loadModuleSource } from './lib/cobol_source.mjs';

const ROOT = path.resolve(process.argv[2] || '.');
const SRC = path.join(ROOT, 'cobol', 'src');

const failures = [];
let checked = 0;

for (const f of readdirSync(SRC)
  .filter((x) => x.endsWith('.cob'))
  .sort()) {
  const src = loadModuleSource(ROOT, f);
  const count = (re) => (src.match(re) || []).length;
  const begin = count(/CALL\s+"SQL_BEGIN"/g);
  const commit = count(/CALL\s+"SQL_COMMIT"/g);
  const rollback = count(/CALL\s+"SQL_ROLLBACK"/g);
  checked += 1;
  if (begin === 0 && commit + rollback > 0) {
    failures.push(`${f}: orphan transaction close (COMMITx${commit}/ROLLBACKx${rollback} without SQL_BEGIN)`);
  }
  if (begin > 0 && (commit === 0 || rollback === 0)) {
    failures.push(
      `${f}: opened transaction not closed on both paths (BEGINx${begin} COMMITx${commit} ROLLBACKx${rollback})`,
    );
  }
}

if (failures.length) {
  console.error('TRANSACTION OWNERSHIP VIOLATIONS (ADR-0006):');
  for (const m of failures) console.error(`  ${m}`);
  process.exit(1);
}

console.log(`OK: transaction ownership holds (${checked} modules, one owner per transaction)`);
