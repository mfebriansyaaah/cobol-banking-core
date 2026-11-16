// Unit tests for scripts/check_schema_unique_tables.mjs (audit P0-04).
// Uses temp dirs, never touches database/schema.sql.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { runGate } from './helpers.mjs';

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeRoot(schemaText) {
  const dir = mkdtempSync(path.join(tmpdir(), 'schema-unique-'));
  dirs.push(dir);
  mkdirSync(path.join(dir, 'database'), { recursive: true });
  writeFileSync(path.join(dir, 'database', 'schema.sql'), schemaText);
  return dir;
}

const clean = `-- header
CREATE TABLE IF NOT EXISTS foo (
    id BIGINT PRIMARY KEY
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS bar (
    id BIGINT PRIMARY KEY
) ENGINE=InnoDB;
`;

const dupIdentical = `-- header
CREATE TABLE IF NOT EXISTS foo (
    id BIGINT PRIMARY KEY
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS foo (
    id BIGINT PRIMARY KEY
) ENGINE=InnoDB;
`;

const dupDifferent = `-- header
CREATE TABLE IF NOT EXISTS foo (
    id BIGINT PRIMARY KEY
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS foo (
    id BIGINT PRIMARY KEY,
    extra INT NULL
) ENGINE=InnoDB;
`;

test('clean schema passes check', () => {
  const root = makeRoot(clean);
  const r = runGate('scripts/check_schema_unique_tables.mjs', ['--check', '--root', root]);
  assert.equal(r.status, 0, `expected 0, got ${r.status}: ${r.stderr}`);
  assert.match(r.stdout, /OK: 2 unique table/);
});

test('duplicate identical blocks fail check but write dedupes', () => {
  const root = makeRoot(dupIdentical);
  const before = runGate('scripts/check_schema_unique_tables.mjs', ['--check', '--root', root]);
  assert.equal(before.status, 1, `expected 1, got ${before.status}: ${before.stderr}`);
  assert.match(before.stderr, /DUPLICATE foo/);
  const w = runGate('scripts/check_schema_unique_tables.mjs', ['--write', '--root', root]);
  assert.equal(w.status, 0, `expected 0, got ${w.status}: ${w.stderr}`);
  const after = runGate('scripts/check_schema_unique_tables.mjs', ['--check', '--root', root]);
  assert.equal(after.status, 0, `expected 0, got ${after.status}: ${after.stderr}`);
  const out = readFileSync(path.join(root, 'database', 'schema.sql'), 'utf8');
  assert.equal(out.match(/^CREATE TABLE/gm).length, 1);
});

test('duplicate differing blocks refuse to write', () => {
  const root = makeRoot(dupDifferent);
  const w = runGate('scripts/check_schema_unique_tables.mjs', ['--write', '--root', root]);
  assert.equal(w.status, 2, `expected 2, got ${w.status}: ${w.stderr}`);
  const out = readFileSync(path.join(root, 'database', 'schema.sql'), 'utf8');
  assert.equal(out, dupDifferent);
});
