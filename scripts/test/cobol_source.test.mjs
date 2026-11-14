// Unit tests for scripts/lib/cobol_source.mjs. No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { expandCopybooks, loadModuleSource } from '../lib/cobol_source.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

test('expands one COPY include in place', () => {
  const d = mkdtempSync(path.join(tmpdir(), 'cobsrc-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'cobol', 'src'), { recursive: true });
  mkdirSync(path.join(d, 'cobol', 'copy'), { recursive: true });
  writeFileSync(path.join(d, 'cobol', 'copy', 'one.cpy'), '        SHARED-PARA.\n            MOVE 1 TO X.\n');
  const out = expandCopybooks('        MAIN-LOGIC.\n        COPY "one.cpy".\n', {
    copyDir: path.join(d, 'cobol', 'copy'),
  });
  assert.match(out, /SHARED-PARA/);
  assert.doesNotMatch(out, /COPY "one\.cpy"/);
});

test('missing include is left alone', () => {
  const d = mkdtempSync(path.join(tmpdir(), 'cobsrc-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'cobol', 'copy'), { recursive: true });
  const out = expandCopybooks('        COPY "nope.cpy".\n', { copyDir: path.join(d, 'cobol', 'copy') });
  assert.match(out, /COPY "nope\.cpy"/);
});

test('COPY cycle throws', () => {
  const d = mkdtempSync(path.join(tmpdir(), 'cobsrc-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'cobol', 'copy'), { recursive: true });
  writeFileSync(path.join(d, 'cobol', 'copy', 'a.cpy'), '        COPY "b.cpy".\n');
  writeFileSync(path.join(d, 'cobol', 'copy', 'b.cpy'), '        COPY "a.cpy".\n');
  assert.throws(
    () => expandCopybooks('        COPY "a.cpy".\n', { copyDir: path.join(d, 'cobol', 'copy') }),
    /COPY cycle/,
  );
});

test('loadModuleSource expands the real tree', () => {
  const out = loadModuleSource(ROOT, 'card_core.cob');
  assert.match(out, /SHARED|COPY|PERFORM/);
  assert.ok(out.length > 1000);
});
