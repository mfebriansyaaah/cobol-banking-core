// Copybook pilot pins (maint-00c). No database, no build.
//
// The pilot extracts ALLOW-ADMIN into cobol/copy/common_auth.cpy for three
// modules (card, collection, deposit). The paragraph is byte-identical
// across modules except the denied-audit target, which the caller sets in
// WS-DENIED-TARGET before PERFORMing. These pins fail if:
//   - a pilot module regrows an inline ALLOW-ADMIN paragraph,
//   - the COPY include goes missing,
//   - any PERFORM ALLOW-ADMIN site forgets to set WS-DENIED-TARGET first,
//   - the copybook hardcodes a module target (it must stay generic).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const COPY_PATH = path.join(ROOT, 'cobol', 'copy', 'common_auth.cpy');

const PILOTS = [
  { module: 'card_core', target: 'CARD_CORE' },
  { module: 'collection_core', target: 'COLLECTION_CORE' },
  { module: 'deposit_core', target: 'DEPOSIT_CORE' },
];

const srcOf = (module) => readFileSync(path.join(ROOT, 'cobol', 'src', `${module}.cob`), 'utf8');

test('common_auth.cpy provides a generic ALLOW-ADMIN', () => {
  const cpy = readFileSync(COPY_PATH, 'utf8');
  assert.match(cpy, /^ {7}ALLOW-ADMIN\.$/m, 'copybook must define ALLOW-ADMIN');
  assert.doesNotMatch(
    cpy,
    /MOVE\s+"[A-Z]+_CORE"\s+TO\s+WS-DENIED-TARGET/,
    'copybook must not hardcode a module target',
  );
  assert.match(cpy, /PERFORM AUDIT-DENIED/, 'copybook delegates to the host AUDIT-DENIED');
});

for (const { module, target } of PILOTS) {
  test(`${module}: no inline ALLOW-ADMIN, COPY include present`, () => {
    const src = srcOf(module);
    assert.doesNotMatch(src, /^ {7}ALLOW-ADMIN\.$/m, 'inline paragraph must be gone');
    assert.match(src, /COPY "common_auth\.cpy"/, 'COPY include must be present');
  });

  test(`${module}: every PERFORM ALLOW-ADMIN sets WS-DENIED-TARGET first`, () => {
    const lines = srcOf(module).split('\n');
    let sites = 0;
    lines.forEach((line, idx) => {
      if (!/^\s*PERFORM ALLOW-ADMIN\s*$/.test(line)) return;
      sites += 1;
      const prev = (lines[idx - 1] || '').trim();
      assert.equal(
        prev,
        `MOVE "${target}" TO WS-DENIED-TARGET`,
        `${module}:${idx + 1}: missing target before PERFORM ALLOW-ADMIN`,
      );
    });
    assert.ok(sites > 0, `${module}: expected PERFORM ALLOW-ADMIN sites`);
  });
}
