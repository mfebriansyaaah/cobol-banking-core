// Unit tests for scripts/generate_domain_tests.mjs (T-016A/T-018).
// Fixture trees only; the live DB verification path (--verify-db) is
// exercised by running real suites, not here.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { planDomain, parseRouteFields, parseAuditFk, buildBlock, parseCli } from '../generate_domain_tests.mjs';

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeRoot({ routesExtra = '', suiteExtra = '', suiteName = 'widget', fk = 'widget_id' } = {}) {
  const d = mkdtempSync(path.join(tmpdir(), 'gentest-'));
  dirs.push(d);
  const routes = path.join(d, 'middleware', 'src', 'routes');
  mkdirSync(routes, { recursive: true });
  writeFileSync(
    path.join(routes, `${suiteName}.js`),
    [
      `export const WIDGET_ROUTES = [`,
      `  { method: 'post', path: '/widgets', action: 'WDG_CREATE', tokenIdentity: 'actor', fields: [{ name: 'wRef', pattern: /x/ }, { name: 'wName', pattern: /x/ }, { name: 'wType', pattern: /x/ }, BLANK, BLANK, ACTOR] },`,
      `  { method: 'post', path: '/widgets/:id/update', action: 'WDG_UPDATE', tokenIdentity: 'actor', fields: [ID, { name: 'wName', pattern: /x/ }, { name: 'wType', pattern: /x/ }, BLANK, BLANK, ACTOR] },`,
      routesExtra,
      `];`,
      '',
    ].join('\n'),
  );
  const cob = path.join(d, 'cobol', 'src');
  mkdirSync(cob, { recursive: true });
  writeFileSync(
    path.join(cob, `${suiteName}_core.cob`),
    [
      `       IDENTIFICATION DIVISION.`,
      `       MOVE "INSERT INTO widget_audit (${fk}, action, actor_email) VALUES (?, ?, ?)" TO WS-PREP-SQL`,
      '',
    ].join('\n'),
  );
  const db = path.join(d, 'tests', 'db');
  mkdirSync(db, { recursive: true });
  writeFileSync(
    path.join(db, `${suiteName}_db_tests.sh`),
    [
      '#!/usr/bin/env bash',
      'db_reset_widget',
      'create_out="$(run_cobol "WDG_CREATE|WDG-1|Gadget|TOOL|||admin@test.com")"',
      'id="$(printf "%s" "$create_out" | awk -F"|" "{print $3}")"',
      suiteExtra,
      'print_summary',
      '',
    ].join('\n'),
  );
  return d;
}

test('plans a uniform domain and emits the UPDATE block', () => {
  const d = makeRoot();
  const plan = planDomain('widget', { root: d });
  assert.equal(plan.stem, 'widget');
  assert.equal(plan.ok, true);
  assert.match(plan.block, /WDG_UPDATE/);
  assert.match(plan.block, /\$\{id\}/);
  assert.match(plan.block, /version bumped/);
  assert.match(plan.block, /non-admin update refused/);
});

test('parseAuditFk reads the FK column from the audit INSERT', () => {
  assert.equal(
    parseAuditFk('MOVE "INSERT INTO widget_audit (widget_id, action) VALUES (?, ?)" TO X', 'widget'),
    'widget_id',
  );
  assert.equal(
    parseAuditFk(
      'move "insert into cost_center_audit (cc_id, action, actor_email, detail) values (?, ?, ?, ?)" to x',
      'cost_center',
    ),
    'cc_id',
  );
  assert.equal(parseAuditFk('no insert here', 'widget'), null);
});

test('skips when the audit INSERT cannot be parsed', () => {
  const d = makeRoot();
  writeFileSync(path.join(d, 'cobol', 'src', 'widget_core.cob'), 'IDENTIFICATION DIVISION.\nno audit insert\n');
  const r = planDomain('widget', { root: d });
  assert.equal(r.ok, false);
  assert.match(r.reason, /INSERT INTO widget_audit/);
});

test('parseRouteFields reads the six UPDATE slots', () => {
  const src = `[{ method: 'post', path: '/x/:id/update', action: 'X_UPDATE', tokenIdentity: 'actor', fields: [ID, { name: 'a', pattern: /x/ }, B, BLANK, BLANK, ACTOR] }]`;
  assert.deepEqual(parseRouteFields(src, 'X_UPDATE'), ['ID', 'a', 'B', 'BLANK', 'BLANK', 'ACTOR']);
});

test('buildBlock renders shell with literal suite variables', () => {
  const out = buildBlock({
    prefix: 'WDG',
    table: 'widget',
    actor: 'admin@test.com',
    updateArgs: ['Gadget', 'TOOL'],
    fk: 'widget_id',
  });
  assert.match(out, /upd_out="\$\(run_cobol "WDG_UPDATE\|\$\{id\}\|Gadget\|TOOL\|\|\|admin@test\.com"\)"/);
  assert.match(out, /SELECT version FROM widget WHERE id=\$\{id\}/);
  assert.match(out, /FROM widget_audit WHERE widget_id=\$\{id\}/);
  assert.match(out, /ver_before=.*SELECT version/);
  assert.match(out, /\^\$\(\(ver_before \+ 1\)\)\$/);
  assert.match(out, /\^\$\(\(aud_before \+ 1\)\)\$/);
});

test('skips when UPDATE route is missing', () => {
  const d = mkdtempSync(path.join(tmpdir(), 'gentest-'));
  dirs.push(d);
  const routes = path.join(d, 'middleware', 'src', 'routes');
  mkdirSync(routes, { recursive: true });
  writeFileSync(
    path.join(routes, 'plain.js'),
    `export const P_ROUTES = [\n  { method: 'post', path: '/p', action: 'P_CREATE', fields: [] },\n];\n`,
  );
  const db = path.join(d, 'tests', 'db');
  mkdirSync(db, { recursive: true });
  writeFileSync(path.join(db, 'plain_db_tests.sh'), '#!/usr/bin/env bash\ndb_reset_plain\nprint_summary\n');
  const r = planDomain('plain', { root: d });
  assert.equal(r.ok, false);
  assert.match(r.reason, /UPDATE/);
});

test('skips when an UPDATE field has no CREATE counterpart', () => {
  const d = mkdtempSync(path.join(tmpdir(), 'gentest-'));
  dirs.push(d);
  const routes = path.join(d, 'middleware', 'src', 'routes');
  mkdirSync(routes, { recursive: true });
  writeFileSync(
    path.join(routes, 'odd.js'),
    [
      `export const O_ROUTES = [`,
      `  { method: 'post', path: '/o', action: 'ODD_CREATE', tokenIdentity: 'actor', fields: [{ name: 'wRef', pattern: /x/ }, BLANK, BLANK, BLANK, BLANK, ACTOR] },`,
      `  { method: 'post', path: '/o/:id/update', action: 'ODD_UPDATE', tokenIdentity: 'actor', fields: [ID, { name: 'mystery', pattern: /x/ }, BLANK, BLANK, BLANK, ACTOR] },`,
      `];`,
      '',
    ].join('\n'),
  );
  const db = path.join(d, 'tests', 'db');
  mkdirSync(db, { recursive: true });
  writeFileSync(
    path.join(db, 'odd_db_tests.sh'),
    [
      '#!/usr/bin/env bash',
      'db_reset_odd',
      'create_out="$(run_cobol "ODD_CREATE|ODD-1|||||admin@test.com")"',
      'id="$(printf "%s" "$create_out" | awk -F"|" "{print $3}")"',
      'print_summary',
      '',
    ].join('\n'),
  );
  const r = planDomain('odd', { root: d });
  assert.equal(r.ok, false);
  assert.match(r.reason, /mystery/);
});

test('skips suites that already carry the block', () => {
  const d = makeRoot({ suiteExtra: '# UPDATE (optimistic locking: version bump + audit).\n' });
  const r = planDomain('widget', { root: d });
  assert.equal(r.ok, true);
  assert.equal(r.skipped, true);
});

test('parseCli parses flags and rejects unknown ones', () => {
  assert.deepEqual(parseCli(['a', 'b']), { root: path.resolve('.'), verifyDb: false, stems: ['a', 'b'] });
  assert.deepEqual(parseCli(['--verify-db', 'a']).verifyDb, true);
  assert.deepEqual(parseCli(['--help']), { help: true });
  assert.throws(() => parseCli(['--bogus']), /unknown argument/);
});
