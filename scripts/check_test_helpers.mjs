// Guard: every db_* helper a suite calls must actually exist in
// tests/lib (db.sh for fixtures, guard.sh for safety rails, ...).
//
// Three suites called reset helpers that were never defined
// (db_reset_ntf_template_config, db_reset_rpt_schedule_config, db_reset_adt_log).
// The shell only warns "command not found", the reset silently did nothing, and
// the first run passed because the table happened to be empty. The second run
// failed. A misspelt helper must be a build error, not a flaky test.
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const libDir = path.join(ROOT, 'tests', 'lib');
const defined = new Set();
for (const f of readdirSync(libDir).filter((x) => x.endsWith('.sh'))) {
  const lib = readFileSync(path.join(libDir, f), 'utf8');
  for (const m of lib.matchAll(/^(\w+)\(\)\s*\{/gm)) defined.add(m[1]);
}

const suitesDir = path.join(ROOT, 'tests', 'db');
const missing = [];

for (const file of readdirSync(suitesDir)
  .filter((f) => f.endsWith('.sh'))
  .sort()) {
  const lines = readFileSync(path.join(suitesDir, file), 'utf8').split('\n');
  lines.forEach((line, idx) => {
    // A helper invocation is a standalone command, optionally with arguments.
    const m = line.match(/^\s*(db_[a-z0-9_]+)(?:\s|$)/);
    if (!m) return;
    if (!defined.has(m[1])) {
      missing.push({ file, line: idx + 1, fn: m[1] });
    }
  });
}

if (missing.length) {
  console.error('UNDEFINED db.sh HELPERS:');
  for (const m of missing) console.error(`  ${m.file}:${m.line}  ${m.fn}()`);
  console.error(`\n${missing.length} call(s) would fail at runtime with "command not found"`);
  process.exit(1);
}

console.log(`OK: every db_* helper used by ${readdirSync(suitesDir).length} suite(s) is defined`);
