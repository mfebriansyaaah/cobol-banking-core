// SQL exec wrapper paragraph pins (DRY-06A rollout). No database, no build.
//
// cobol/copy/sql_exec_6.cpy must provide one paragraph per converted arity:
// each runs CALL "SQL_PREPARE_EXEC[_ROWS]" with BY VALUE n binding exactly
// WS-BIND-1..n, then CALL "GET_RESULT". Adding a paragraph here without a
// performer fails check_copybooks (dead paragraph); converting a site to a
// missing paragraph fails check_bind_slots. This file pins the contract so
// a copybook edit cannot silently drift from either gate.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const CPY = readFileSync(path.join(ROOT, 'cobol', 'copy', 'sql_exec_6.cpy'), 'utf8');

const PARAGRAPHS = [
  ['SQL-EXEC-0', 'SQL_PREPARE_EXEC', 0],
  ['SQL-EXEC-1', 'SQL_PREPARE_EXEC', 1],
  ['SQL-EXEC-2', 'SQL_PREPARE_EXEC', 2],
  ['SQL-EXEC-3', 'SQL_PREPARE_EXEC', 3],
  ['SQL-EXEC-4', 'SQL_PREPARE_EXEC', 4],
  ['SQL-EXEC-5', 'SQL_PREPARE_EXEC', 5],
  ['SQL-EXEC-6', 'SQL_PREPARE_EXEC', 6],
  ['SQL-EXEC-ROWS-0', 'SQL_PREPARE_EXEC_ROWS', 0],
  ['SQL-EXEC-ROWS-1', 'SQL_PREPARE_EXEC_ROWS', 1],
  ['SQL-EXEC-ROWS-2', 'SQL_PREPARE_EXEC_ROWS', 2],
  ['SQL-EXEC-ROWS-3', 'SQL_PREPARE_EXEC_ROWS', 3],
  ['SQL-EXEC-ROWS-4', 'SQL_PREPARE_EXEC_ROWS', 4],
  ['SQL-EXEC-ROWS-5', 'SQL_PREPARE_EXEC_ROWS', 5],
  ['SQL-EXEC-ROWS-6', 'SQL_PREPARE_EXEC_ROWS', 6],
  ['SQL-EXEC-LOCK-1', 'SQL_PREPARE_EXEC_LOCK', 1],
  ['SQL-EXEC-LOCK-2', 'SQL_PREPARE_EXEC_LOCK', 2],
];

function blockOf(name) {
  const start = CPY.search(new RegExp(`^ {7,8}${name}\\.$`, 'm'));
  assert.notEqual(start, -1, `missing paragraph ${name}`);
  const rest = CPY.slice(start);
  const next = rest.slice(1).search(/^ {7,8}SQL-EXEC/m);
  return next === -1 ? rest : rest.slice(0, next + 1);
}

for (const [name, call, arity] of PARAGRAPHS) {
  test(`${name} binds exactly 1..${arity} via ${call}`, () => {
    const block = blockOf(name);
    assert.match(block, new RegExp(`CALL "${call}" USING BY REFERENCE WS-PREP-SQL BY VALUE ${arity}`));
    for (let s = 1; s <= arity; s += 1) {
      assert.match(block, new RegExp(`BY REFERENCE WS-BIND-${s}\\b`), `${name} must pass WS-BIND-${s}`);
    }
    assert.doesNotMatch(
      block,
      new RegExp(`BY REFERENCE WS-BIND-${arity + 1}\\b`),
      `${name} must not pass a stale WS-BIND-${arity + 1}`,
    );
    assert.match(block, /CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL/);
  });
}
