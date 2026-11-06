// Unit tests for the warning baseline completeness rule (CI-014).
// Every core COBOL module must have an entry in tests/warning_baseline.txt:
// without one, new modules silently escape the warning ratchet.
// main_logic.cob and sql_bridge.c are covered too. No build needed.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

function baselineKeys() {
  const keys = [];
  for (const line of readFileSync(path.join(ROOT, 'tests', 'warning_baseline.txt'), 'utf8').split('\n')) {
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq > 0) keys.push(line.slice(0, eq).trim());
  }
  return keys;
}

function coreModules() {
  const names = readdirSync(path.join(ROOT, 'cobol', 'src'))
    .filter((f) => f.endsWith('_core.cob'))
    .sort();
  return [...names, 'main_logic.cob', 'sql_bridge.c'];
}

test('every core module has a warning baseline entry', () => {
  const keys = new Set(baselineKeys());
  const missing = coreModules().filter((m) => !keys.has(m));
  assert.deepEqual(
    missing,
    [],
    `modules without a baseline entry (add <file>=0 after measuring):\n${missing.join('\n')}`,
  );
});

test('baseline has no duplicate entries', () => {
  const keys = baselineKeys();
  const dupes = keys.filter((k, i) => keys.indexOf(k) !== i);
  assert.deepEqual([...new Set(dupes)], [], 'duplicate baseline entries');
});
