// DB-operations relevance classifier.
//
// `db_ops_relevant` is true only when the change set can alter the schema,
// migrations, backup/restore tooling, or the drills themselves. The post-merge
// `db-ops` job then runs on pushes that can change that surface; ordinary code
// pushes rely on the nightly drills instead.
//
// Empty or unreadable input fails safe to `true` (never skip a drill when the
// change set is unknown).
//
// Usage: printf '%s\n' <files> | node scripts/ci/classify_db_ops.mjs --stdin
import { readFileSync } from 'node:fs';

const RELEVANT = [
  /^database\//,
  /^scripts\/ci\/(migration_rollback_drill|backup_restore_drill|restore_drill|build_db_snapshot|restore_db_snapshot|classify_db_ops)\.sh$/,
  /^scripts\/ci\/classify_db_ops\.mjs$/,
  /^scripts\/(check_schema_drift|generate_schema_snapshot)\.sh$/,
  /^tests\/db\/migration_/,
  /^tests\/scripts\/test_(db_snapshot|restore|db_guard|schema_drift)/,
];

/** True when at least one path can change the DB-operations surface. */
export function isDbOpsRelevant(files) {
  const list = (files || []).map((f) => String(f).trim()).filter(Boolean);
  if (!list.length) return true;
  return list.some((f) => RELEVANT.some((re) => re.test(f)));
}

function readStdin() {
  let s = '';
  try {
    s = readFileSync(0, 'utf8');
  } catch {
    return '';
  }
  return s;
}

const args = process.argv.slice(2);
if (args.includes('--help') || args.includes('-h')) {
  console.log('usage: classify_db_ops.mjs [--stdin] [files...]');
  process.exit(0);
}
const files = args.filter((a) => a !== '--stdin');
if (args.includes('--stdin')) files.push(...readStdin().split('\n'));
console.log(`db_ops_relevant=${isDbOpsRelevant(files)}`);
