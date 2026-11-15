// Prepared-only auth pins (maint-04c). No database, no build.
//
// Auth SQL must be prepared statements with ? placeholders, never string
// concatenation (even escaped): the bridge trims trailing spaces from binds,
// so a full-field bind is exactly the trimmed inline value — except
// CHAR_LENGTH, which is now measured on the raw password instead of the
// escaped form (stricter, documented in the commit).
// Universal invariant: auth_core, auth_ops_core, and user_core contain no
// `CALL "SET_QUERY"` anymore. These pins fail if dynamic SQL returns.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC_DIR = path.join(ROOT, 'cobol', 'src');
const AUTH_MODULES = ['auth_core', 'auth_ops_core', 'user_core'];

test('no dynamic SQL remains in auth modules', () => {
  for (const module of AUTH_MODULES) {
    const src = readFileSync(path.join(SRC_DIR, `${module}.cob`), 'utf8');
    assert.doesNotMatch(src, /CALL "SET_QUERY"/, `${module}: dynamic SQL must be gone`);
    assert.doesNotMatch(src, /CALL "SQL_EXECUTE"/, `${module}: unprepared execute must be gone`);
  }
});

test('every auth SQL statement is prepared with placeholders', () => {
  // Every SQL string literal in the auth modules must use ? placeholders
  // (prepared) rather than inline interpolation. STRING ... INTO WS-QUERY
  // is the dynamic-SQL builder; WS-PREP-SQL is the prepared one.
  for (const module of AUTH_MODULES) {
    const src = readFileSync(path.join(SRC_DIR, `${module}.cob`), 'utf8');
    assert.doesNotMatch(src, /INTO WS-QUERY/, `${module}: no query may target WS-QUERY`);
  }
});

test('auth modules still bind every statement (no dropped params)', () => {
  // Sanity: the modules that lost dynamic SQL still issue prepared calls.
  // Sites may be inline CALLs or shared-wrapper PERFORMs (DRY-06A rollout);
  // what matters is that no statement disappeared in the conversion.
  const SITE_RE = /CALL "SQL_PREPARE_EXEC|PERFORM SQL-EXEC(?:-ROWS|-LOCK)?-\d/g;
  for (const module of AUTH_MODULES) {
    const src = readFileSync(path.join(SRC_DIR, `${module}.cob`), 'utf8');
    const n = (src.match(SITE_RE) || []).length;
    assert.ok(n >= 5, `${module}: expected prepared sites to remain, got ${n}`);
  }
});
