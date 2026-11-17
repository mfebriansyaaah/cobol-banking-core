// Unit tests for scripts/generate_data_dictionary.mjs (docs hygiene).
// No database, no build: the generator parses SQL text, so tests run it
// against a temp mini schema covering the shapes found in production.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { generateDataDictionary } from '../generate_data_dictionary.mjs';
import { runGate } from './helpers.mjs';

const MINI_SCHEMA = [
  'CREATE TABLE IF NOT EXISTS users (',
  '    id INT AUTO_INCREMENT PRIMARY KEY,',
  '    email VARCHAR(100) NOT NULL UNIQUE,',
  "    role ENUM('USER', 'MANAGER') DEFAULT 'USER',",
  "    motto ENUM('A', 'B C') NOT NULL,",
  '    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,',
  '    INDEX idx_users_email (email),',
  ') ENGINE=InnoDB;',
  '',
  'CREATE TABLE IF NOT EXISTS audit_trail (',
  '    id BIGINT AUTO_INCREMENT PRIMARY KEY,',
  '    user_id BIGINT NOT NULL,',
  '    detail VARCHAR(255),',
  '    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id),',
  ') ENGINE=InnoDB;',
  '',
  'CREATE TABLE IF NOT EXISTS orphan_ref (',
  '    id INT AUTO_INCREMENT PRIMARY KEY,',
  '    REFERENCES audit_trail(id),',
  ') ENGINE=InnoDB;',
  '',
].join('\n');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeSchemaRoot() {
  const root = mkdtempSync(path.join(tmpdir(), 'dd-fixture-'));
  dirs.push(root);
  mkdirSync(path.join(root, 'database'), { recursive: true });
  mkdirSync(path.join(root, 'docs'), { recursive: true });
  writeFileSync(path.join(root, 'database', 'schema.sql'), MINI_SCHEMA);
  return root;
}

test('generates one section per table with trimmed types and sorted groups', () => {
  const root = makeSchemaRoot();
  const out = generateDataDictionary(root);
  assert.match(out, /3 tables\./);
  assert.match(out, /## Domain group: `audit_\*`/);
  assert.match(out, /## Domain group: `orphan_\*`/);
  assert.match(out, /## Domain group: `users_\*`/);
  assert.ok(out.indexOf('## Domain group: `audit_') < out.indexOf('## Domain group: `orphan_'));
  assert.match(
    out,
    /\| id \| INT AUTO_INCREMENT \|\n\| email \| VARCHAR\(100\) NOT \|\n\| role \| ENUM\('USER', 'MANAGER'\) DEFAULT \|\n\| motto \| ENUM\('A', 'B C'\) NOT \|\n\| created_at \| TIMESTAMP DEFAULT \|/,
  );
});

test('constraint and index lines never leak into the column list', () => {
  const root = makeSchemaRoot();
  const out = generateDataDictionary(root);
  assert.doesNotMatch(out, /FOREIGN|CONSTRAINT|REFERENCES|INDEX/);
  assert.match(out, /\| user_id \| BIGINT NOT \|\n\| detail \| VARCHAR\(255\) \|/);
});

test('generate_data_dictionary.mjs --check passes after --write and fails when stale', () => {
  const root = makeSchemaRoot();
  const wrote = runGate('scripts/generate_data_dictionary.mjs', ['--write', root]);
  assert.equal(wrote.status, 0, `generator --write failed: ${wrote.stderr}`);
  const checked = runGate('scripts/generate_data_dictionary.mjs', ['--check', root]);
  assert.equal(checked.status, 0, `generator --check failed: ${checked.stderr}`);
  const doc = path.join(root, 'docs', 'DATA_DICTIONARY.md');
  writeFileSync(doc, readFileSync(doc, 'utf8') + '\n# tamper\n');
  const stale = runGate('scripts/generate_data_dictionary.mjs', ['--check', root]);
  assert.equal(stale.status, 1, 'generator --check should fail on a stale dictionary');
});
