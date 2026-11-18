// Unit tests for the living-docs module-reference gate.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { missingModules } from '../check_docs_modules.mjs';

test('reports a backticked module with no source file', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'docs-modules-'));
  try {
    mkdirSync(path.join(dir, 'docs', 'archive'), { recursive: true });
    mkdirSync(path.join(dir, 'cobol', 'src'), { recursive: true });
    writeFileSync(path.join(dir, 'cobol', 'src', 'auth_core.cob'), 'IDENTIFICATION DIVISION.\n');
    writeFileSync(path.join(dir, 'README.md'), 'Use `auth_core` and never `missing_core`.\n');
    writeFileSync(path.join(dir, 'docs', 'archive', 'old.md'), 'Historical `retired_core`.\n');
    const missing = missingModules(dir);
    assert.deepEqual(
      missing.map((m) => [m.file, m.module]),
      [['README.md', 'missing_core']],
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
