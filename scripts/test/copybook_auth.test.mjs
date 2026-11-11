// ALLOW-ADMIN copybook pins (maint-00c pilot, maint-03a rollout).
// No database, no build.
//
// The paragraph is byte-identical across modules except the denied-audit
// target, which each caller sets in WS-DENIED-TARGET before PERFORMing.
// Universal invariant: every module that PERFORMs ALLOW-ADMIN must get it
// from common_auth.cpy (no inline copy), set exactly one target, and set it
// immediately before every PERFORM site. These pins fail if:
//   - a module regrows an inline ALLOW-ADMIN paragraph,
//   - the COPY include goes missing,
//   - any PERFORM ALLOW-ADMIN site forgets to set WS-DENIED-TARGET first,
//   - a module sets two different targets (ambiguous audit trail),
//   - the copybook hardcodes a module target (it must stay generic).
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
const callers = modules.filter((m) => /^\s*PERFORM ALLOW-ADMIN\s*$/m.test(srcOf(m)));

// Documented exceptions (keep inline, do not convert):
//   - user_core: 4-param linkage (actor=P3, target=P1); its ALLOW-ADMIN reads
//     WS-PARAM3/TRIMMED and sets a dynamic target, so the shared paragraph
//     does not apply.
const INLINE_OK = new Set(['user_core']);

test('common_auth.cpy provides a generic ALLOW-ADMIN', () => {
  const cpy = readFileSync(COPY_PATH, 'utf8');
  assert.match(cpy, /^ {7}ALLOW-ADMIN\.$/m, 'copybook must define ALLOW-ADMIN');
  assert.doesNotMatch(cpy, /MOVE\s+"[A-Z0-9_]+" TO\s+WS-DENIED-TARGET/, 'copybook must not hardcode a module target');
  assert.match(cpy, /PERFORM AUDIT-DENIED/, 'copybook delegates to the host AUDIT-DENIED');
});

test(`every ALLOW-ADMIN caller uses the copybook (${callers.length} modules)`, () => {
  assert.ok(callers.length >= 40, `expected 40+ converted callers, got ${callers.length}`);
  for (const module of callers) {
    if (INLINE_OK.has(module)) continue;
    const src = srcOf(module);
    assert.doesNotMatch(src, /^ {7,8}ALLOW-ADMIN\.$/m, `${module}: inline paragraph must be gone`);
    assert.match(src, /COPY "common_auth\.cpy"/, `${module}: COPY include must be present`);
  }
});

test('every caller sets exactly one target, immediately before each PERFORM', () => {
  for (const module of callers) {
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
      if (!/^\s*PERFORM ALLOW-ADMIN\s*$/.test(line)) return;
      sites += 1;
      assert.equal(
        (lines[idx - 1] || '').trim(),
        `MOVE "${target}" TO WS-DENIED-TARGET`,
        `${module}:${idx + 1}: missing target before PERFORM ALLOW-ADMIN`,
      );
    });
    assert.ok(sites > 0, `${module}: expected PERFORM ALLOW-ADMIN sites`);
  }
});
