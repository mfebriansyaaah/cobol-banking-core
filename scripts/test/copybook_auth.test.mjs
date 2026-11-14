// ADMIN-GUARD copybook pins (maint-00c pilot, maint-03a rollout,
// DRY-06B guard sharing). No database, no build.
//
// ADMIN-GUARD centralizes the 6-line admin prologue: the caller sets
// WS-DENIED-TARGET, PERFORMs ADMIN-GUARD (shared ALLOW-ADMIN + the single
// ERROR|FORBIDDEN output), then exits unless WS-ALLOWED. No new working
// storage: WS-ALLOWED already carries the verdict, and a 01 inside the
// procedure-division copybook would not compile.
// Universal invariant: every module that guards with ADMIN-GUARD must get
// it from common_auth.cpy, set exactly one target, and set it immediately
// before every PERFORM site. These pins fail if:
//   - a module regrows an inline ALLOW-ADMIN paragraph,
//   - the COPY include goes missing,
//   - any PERFORM ADMIN-GUARD site forgets to set WS-DENIED-TARGET first,
//   - a module sets two different targets (ambiguous audit trail),
//   - the copybook hardcodes a module target (it must stay generic),
//   - any module outside INLINE_OK PERFORMs ALLOW-ADMIN directly.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC_DIR = path.join(ROOT, 'cobol', 'src');
const COPY_PATH = path.join(ROOT, 'cobol', 'copy', 'common_auth.cpy');

const modules = readdirSync(SRC_DIR)
  .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob')
  .map((f) => f.replace(/\.cob$/, ''))
  .sort();
const srcOf = (module) => readFileSync(path.join(SRC_DIR, `${module}.cob`), 'utf8');
const guarders = modules.filter((m) => /^\s*PERFORM ADMIN-GUARD(-RESULT)?\s*$/m.test(srcOf(m)));

// Documented exceptions (keep inline, do not convert):
//   - user_core: 4-param linkage (actor=P3, target=P1); its ALLOW-ADMIN reads
//     WS-PARAM3/TRIMMED and sets a dynamic target, so the shared guard
//     does not apply.
const INLINE_OK = new Set(['user_core']);

test('common_auth.cpy provides generic ALLOW-ADMIN and ADMIN-GUARD', () => {
  const cpy = readFileSync(COPY_PATH, 'utf8');
  assert.match(cpy, /^ {7}ALLOW-ADMIN\.$/m, 'copybook must define ALLOW-ADMIN');
  assert.match(cpy, /^ {7}ADMIN-GUARD\.$/m, 'copybook must define ADMIN-GUARD');
  assert.match(cpy, /^ {7}ADMIN-GUARD-RESULT\.$/m, 'copybook must define ADMIN-GUARD-RESULT');
  assert.doesNotMatch(cpy, /MOVE\s+"[A-Z0-9_]+" TO\s+WS-DENIED-TARGET/, 'copybook must not hardcode a module target');
  assert.match(cpy, /PERFORM ALLOW-ADMIN/, 'guard must run the shared ALLOW-ADMIN');
  assert.match(cpy, /MOVE "ERROR\|FORBIDDEN" TO LS-OUTPUT-BUFFER/, 'guard must own the FORBIDDEN output');
  assert.match(cpy, /PERFORM AUDIT-DENIED/, 'copybook delegates to the host AUDIT-DENIED');
});

test(`every guarded module uses the copybook (${guarders.length} modules)`, () => {
  assert.ok(guarders.length >= 40, `expected 40+ converted callers, got ${guarders.length}`);
  for (const module of guarders) {
    if (INLINE_OK.has(module)) continue;
    const src = srcOf(module);
    assert.doesNotMatch(src, /^ {7,8}ALLOW-ADMIN\.$/m, `${module}: inline paragraph must be gone`);
    assert.match(src, /COPY "common_auth\.cpy"/, `${module}: COPY include must be present`);
  }
});

test('no module outside INLINE_OK PERFORMs ALLOW-ADMIN directly', () => {
  const offenders = [];
  for (const module of modules) {
    if (INLINE_OK.has(module)) continue;
    if (/^\s*PERFORM ALLOW-ADMIN\s*$/m.test(srcOf(module))) offenders.push(module);
  }
  assert.deepEqual(offenders, []);
});

test('every caller sets exactly one target, immediately before each PERFORM', () => {
  for (const module of guarders) {
    if (INLINE_OK.has(module)) continue;
    const lines = srcOf(module).split('\n');
    const targets = new Set();
    for (const line of lines) {
      const m = line.match(/MOVE "([A-Z0-9_]+)" TO WS-DENIED-TARGET/);
      if (m) targets.add(m[1]);
    }
    assert.equal(targets.size, 1, `${module}: expected exactly one denied target, got ${[...targets]}`);
    const [target] = targets;
    let sites = 0;
    lines.forEach((line, idx) => {
      const gm = line.match(/^\s*PERFORM (ADMIN-GUARD(?:-RESULT)?)\s*$/);
      if (!gm) return;
      sites += 1;
      assert.equal(
        (lines[idx - 1] || '').trim(),
        `MOVE "${target}" TO WS-DENIED-TARGET`,
        `${module}:${idx + 1}: missing target before PERFORM ${gm[1]}`,
      );
      const after = lines.slice(idx + 1, idx + 4).join('\n');
      assert.match(after, /IF WS-ALLOWED NOT = 1/, `${module}:${idx + 1}: missing WS-ALLOWED check after guard`);
      assert.match(after, /EXIT PARAGRAPH/, `${module}:${idx + 1}: missing EXIT after guard`);
    });
    assert.ok(sites > 0, `${module}: expected PERFORM ADMIN-GUARD sites`);
  }
});

test('user_core keeps its own inline ALLOW-ADMIN', () => {
  const src = srcOf('user_core');
  assert.match(src, /^ {7,8}ALLOW-ADMIN\.$/m, 'user_core keeps its 4-param variant');
  assert.doesNotMatch(src, /COPY "common_auth\.cpy"/, 'user_core must not take the shared guard');
});
