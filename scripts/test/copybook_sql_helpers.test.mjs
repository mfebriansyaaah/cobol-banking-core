// SQL helper copybook pins (maint-04b). No database, no build.
//
// Three single-purpose lookups plus the AUTHZ_DENIED audit insert share one
// shape: caller stages WS-BIND slots, PERFORMs the shared paragraph, reads
// WS-RESULT. All four are byte-identical across sites except the staged
// values, so the copybook holds the SQL + CALL + GET_RESULT and the caller
// keeps only its staging MOVEs. Universal invariant: no inline copy of any
// of the four statements may remain; every PERFORM site stages its binds
// immediately before. These pins fail if:
//   - an inline helper statement regrows anywhere,
//   - the COPY include goes missing from a using module,
//   - any PERFORM site forgets to stage WS-BIND-1 first,
//   - the copybook hardcodes a staged value or needs an undeclared slot.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC_DIR = path.join(ROOT, 'cobol', 'src');
const COPY_PATH = path.join(ROOT, 'cobol', 'copy', 'common_sql.cpy');

const HELPERS = [
  {
    name: 'LOOKUP-USER-ID',
    sql: 'SELECT CAST(id AS CHAR) FROM users WHERE email = ? LIMIT 1',
    binds: 1,
    staged: true,
  },
  {
    name: 'LAST-INSERT-ID',
    sql: 'SELECT LAST_INSERT_ID()',
    binds: 0,
    staged: false,
  },
  {
    name: 'LOOKUP-CURRENCY',
    sql: 'SELECT currency_id FROM currencies WHERE iso_code = ? LIMIT 1',
    binds: 1,
    staged: true,
  },
  {
    name: 'RECORD-AUTHZ-DENIED',
    sql: "'AUTHZ_DENIED', 'USER'",
    binds: 3,
    staged: true,
  },
];

const modules = readdirSync(SRC_DIR)
  .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob')
  .map((f) => f.replace(/\.cob$/, ''))
  .sort();
const srcOf = (module) => readFileSync(path.join(SRC_DIR, `${module}.cob`), 'utf8');

test('common_sql.cpy provides the four generic helpers', () => {
  const raw = readFileSync(COPY_PATH, 'utf8');
  const code = raw
    .split('\n')
    .filter((l) => !l.trim().startsWith('*>'))
    .join('\n');
  for (const h of HELPERS) {
    assert.match(raw, new RegExp(`^ {7}${h.name}\\.$`, 'm'), `copybook must define ${h.name}`);
    assert.ok(raw.includes(h.sql), `copybook must hold the ${h.name} statement`);
    assert.doesNotMatch(code, /MOVE .+ TO WS-BIND-1/, `${h.name}: copybook must not stage binds`);
  }
  assert.doesNotMatch(code, /WS-BIND-6/, 'shared helpers must not need WS-BIND-6 (4-param hosts lack it)');
});

test('no inline helper statement remains in any module', () => {
  const offenders = [];
  for (const module of modules) {
    const src = srcOf(module);
    for (const h of HELPERS) {
      if (src.includes(h.sql)) offenders.push(`${module}: inline ${h.name} statement`);
    }
  }
  assert.deepEqual(offenders, []);
});

test('every PERFORM stages its binds first (or needs none)', () => {
  let sites = 0;
  for (const module of modules) {
    const src = srcOf(module);
    const hasCopy = /COPY "common_sql\.cpy"/.test(src);
    const lines = src.split('\n');
    for (const h of HELPERS) {
      const re = new RegExp(`^\\s*PERFORM ${h.name}\\s*$`);
      const need = h.name === 'RECORD-AUTHZ-DENIED' ? ['1', '2', '3'] : h.binds > 0 ? ['1'] : [];
      lines.forEach((line, idx) => {
        if (!re.test(line)) return;
        sites += 1;
        assert.ok(hasCopy, `${module}: COPY include must be present`);
        if (need.length === 0) return; // LAST-INSERT-ID stages nothing; nearby MOVEs belong to other statements
        const staged = new Set();
        for (let j = idx - 1; j >= 0; j -= 1) {
          const m = lines[j].trim().match(/^MOVE .+ TO WS-BIND-(\d)$/);
          if (!m) break;
          staged.add(m[1]);
        }
        assert.deepEqual(
          [...staged].sort(),
          need,
          `${module}:${idx + 1}: binds staged immediately before PERFORM ${h.name}: [${[...staged]}]`,
        );
      });
    }
  }
  assert.ok(sites >= 100, `expected 100+ converted sites, got ${sites}`);
});
