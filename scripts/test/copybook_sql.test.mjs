// LOOKUP-USER-ROLE copybook pins (maint-04a). No database, no build.
//
// The role lookup is byte-identical everywhere except the email source, so
// the caller stages WS-BIND-1 and PERFORMs the shared paragraph, which runs
// the single-bind prepared SELECT and leaves the role in WS-RESULT.
// Universal invariant: no inline `SELECT role FROM users WHERE email`
// remains anywhere; every PERFORM site stages WS-BIND-1 on the immediately
// preceding line. These pins fail if:
//   - an inline role lookup regrows anywhere,
//   - the COPY include goes missing from a using module,
//   - any PERFORM site forgets to stage WS-BIND-1 first,
//   - the copybook hardcodes an email source or a second bind.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC_DIR = path.join(ROOT, 'cobol', 'src');
const COPY_PATH = path.join(ROOT, 'cobol', 'copy', 'common_sql.cpy');

const modules = readdirSync(SRC_DIR)
  .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob')
  .map((f) => f.replace(/\.cob$/, ''))
  .sort();
const srcOf = (module) => readFileSync(path.join(SRC_DIR, `${module}.cob`), 'utf8');
const performers = modules.filter((m) => /^\s*PERFORM LOOKUP-USER-ROLE\s*$/m.test(srcOf(m)));

test('common_sql.cpy provides a generic single-bind LOOKUP-USER-ROLE', () => {
  const raw = readFileSync(COPY_PATH, 'utf8');
  assert.match(raw, /^ {7}LOOKUP-USER-ROLE\.$/m, 'copybook must define LOOKUP-USER-ROLE');
  assert.match(raw, /SELECT role FROM users WHERE email = \? LIMIT 1/, 'copybook holds the query');
  assert.match(raw, /BY VALUE 1/, 'copybook binds exactly one slot');
  const code = raw
    .split('\n')
    .filter((l) => !l.trim().startsWith('*>'))
    .join('\n');
  assert.doesNotMatch(code, /MOVE .+ TO WS-BIND-1/, 'copybook must not stage the email (caller does)');
  assert.doesNotMatch(code, /WS-BIND-6/, 'copybook must not need WS-BIND-6 (4-param hosts lack it)');
});

test('no inline role lookup remains in any module', () => {
  const offenders = [];
  for (const module of modules) {
    if (/SELECT role FROM users WHERE email/.test(srcOf(module))) offenders.push(module);
  }
  assert.deepEqual(offenders, []);
});

test(`every performer stages WS-BIND-1 first (${performers.length} modules)`, () => {
  assert.ok(performers.length >= 15, `expected 15+ converted modules, got ${performers.length}`);
  for (const module of performers) {
    const src = srcOf(module);
    assert.match(src, /COPY "common_sql\.cpy"/, `${module}: COPY include must be present`);
    const lines = src.split('\n');
    let sites = 0;
    lines.forEach((line, idx) => {
      if (!/^\s*PERFORM LOOKUP-USER-ROLE\s*$/.test(line)) return;
      sites += 1;
      assert.match(
        (lines[idx - 1] || '').trim(),
        /^MOVE .+ TO WS-BIND-1$/,
        `${module}:${idx + 1}: missing email staging before PERFORM LOOKUP-USER-ROLE`,
      );
    });
    assert.ok(sites > 0, `${module}: expected PERFORM sites`);
  }
});
