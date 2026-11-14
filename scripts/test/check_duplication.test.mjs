// Duplication gate pins (DRY-00A). No database, no build.
//
// The duplication baseline must exist and the gate must pass on the
// current tree. This test shells out to scripts/check_duplication.mjs
// --check; it fails when duplication grows (or shrinks without a
// reviewed --write).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

test('duplication gate passes on the current tree', () => {
  const out = execFileSync('node', [path.join(ROOT, 'scripts', 'check_duplication.mjs'), '--check', ROOT], {
    encoding: 'utf8',
  });
  assert.match(out, /OK: duplication holds/);
});
