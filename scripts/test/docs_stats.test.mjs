// Unit tests for scripts/docs_stats.mjs (P1-9). No database, no build.
// collect() runs in a spawned process against the fixture mini repo;
// pure render/update helpers are imported directly.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { makeFixtureRoot, cleanupFixture, runGate } from './helpers.mjs';
import { updateReadme, renderStatus, renderReadmeBlock } from '../docs_stats.mjs';

const roots = [];
after(() => {
  for (const d of roots) cleanupFixture(d);
});

function collect(root) {
  const r = runGate('scripts/docs_stats.mjs', [root]);
  assert.equal(r.status, 0, `docs_stats failed: ${r.stderr}`);
  return JSON.parse(r.stdout);
}

test('collect counts the fixture tree', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = collect(root);
  assert.equal(s.cobolModules, 2);
  assert.equal(s.cobolFiles, 2);
  assert.equal(s.routeFiles, 2);
  assert.equal(s.actions, 4);
  assert.equal(s.migrations, 2);
  assert.equal(s.tables, 2);
  const programs = s.modules.map((m) => m.source).sort();
  assert.deepEqual(programs, ['account_core.cob', 'loan_core.cob']);
});

test('collect links routes, cases, and db suites per module', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = collect(root);
  const byModule = Object.fromEntries(s.modules.map((m) => [m.module, m]));
  assert.equal(byModule.account_core.route, 'account.js');
  assert.equal(byModule.account_core.cases, 'account.cases');
  assert.equal(byModule.account_core.db, 'account_db_tests.sh');
  assert.equal(byModule.loan_core.route, 'loan.js');
});

test('rendered output embeds the generated stats', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = collect(root);
  const status = renderStatus(s);
  assert.match(status, /COBOL modules in manifest \| 2/);
  assert.match(status, /Recorded migrations \| 2/);
  const block = renderReadmeBlock(s);
  assert.match(block, /<!-- BEGIN GENERATED STATS -->/);
  assert.match(block, /\| COBOL modules \| \*\*2\*\*/);
});

test('updateReadme splices the block between markers', () => {
  const before = 'head\n<!-- BEGIN GENERATED STATS -->\nold\n';
  const after = '<!-- END GENERATED STATS -->\ntail\n';
  const out = updateReadme(before + after, 'NEW');
  assert.equal(out, 'head\nNEW\ntail\n');
});

test('updateReadme throws without markers', () => {
  assert.throws(() => updateReadme('no markers here', 'X'));
});
