// Unit tests for scripts/ci/classify_db_ops.mjs.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { isDbOpsRelevant } from '../ci/classify_db_ops.mjs';

const TOOL = new URL('../ci/classify_db_ops.mjs', import.meta.url).pathname;
const CASES = [
  [['database/schema.sql'], true],
  [['database/migrations/0667_x.sql'], true],
  [['scripts/ci/migration_rollback_drill.sh'], true],
  [['scripts/ci/backup_restore_drill.sh'], true],
  [['scripts/check_schema_drift.sh'], true],
  [['tests/db/migration_baseline_db_tests.sh'], true],
  [['cobol/src/loan_core.cob'], false],
  [['middleware/src/routes/account.js'], false],
  [['tests/db/loan_db_tests.sh'], false],
  [['docs/CI.md'], false],
  [[], true],
];

for (const [files, expected] of CASES) {
  test(`isDbOpsRelevant([${files.join(', ')}]) === ${expected}`, () => {
    assert.equal(isDbOpsRelevant(files), expected);
  });
}

test('CLI prints db_ops_relevant=true for a migration via --stdin', () => {
  const out = execFileSync(process.execPath, [TOOL, '--stdin'], {
    input: 'database/migrations/0667_x.sql\n',
    encoding: 'utf8',
  });
  assert.match(out, /^db_ops_relevant=true/m);
});

test('CLI prints db_ops_relevant=false for a code-only change via --stdin', () => {
  const out = execFileSync(process.execPath, [TOOL, '--stdin'], {
    input: 'middleware/src/app.js\n',
    encoding: 'utf8',
  });
  assert.match(out, /^db_ops_relevant=false/m);
});
