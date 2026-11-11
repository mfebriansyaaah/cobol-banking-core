// Unit tests for scripts/pr_size.mjs (maint-00). No database, no build.
// Pure helpers are imported directly; the git CLI path is covered by
// parseNumstat + summarize, not by spawning git in tests.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { classifyFile, parseNumstat, summarize } from '../pr_size.mjs';

test('generated paths classify as generated', () => {
  for (const f of [
    'manifest/modules.json',
    'contracts/actions.yaml',
    'docs/STATUS.md',
    'docs/MODULE_INDEX.md',
    'docs/openapi.yaml',
    'tests/contracts/route_field_order.json',
    'database/schema_full.sql',
    'database/schema_v2.sql',
    'artifacts/report.tsv',
    'coverage/summary.json',
  ]) {
    assert.equal(classifyFile(f), 'generated', f);
  }
});

test('hand-written paths classify as reviewable', () => {
  for (const f of [
    'docs/BRANCHING.md',
    'docs/GOVERNANCE.md',
    'CONTRIBUTING.md',
    'cobol/src/card_core.cob',
    'middleware/src/app.js',
    'scripts/check_docs.mjs',
    'README.md',
  ]) {
    assert.equal(classifyFile(f), 'reviewable', f);
  }
});

test('parseNumstat parses added/deleted/file and skips noise', () => {
  const rows = parseNumstat('10\t3\ta.js\n0\t5\tb.js\nbinary noise\n-\t-\tc.bin\n');
  assert.deepEqual(rows, [
    { added: 10, deleted: 3, file: 'a.js' },
    { added: 0, deleted: 5, file: 'b.js' },
    { added: 0, deleted: 0, file: 'c.bin' },
  ]);
});

test('summarize splits total into generated and reviewable', () => {
  const s = summarize([
    { added: 10, deleted: 3, file: 'middleware/src/app.js' },
    { added: 100, deleted: 50, file: 'manifest/modules.json' },
    { added: 5, deleted: 5, file: 'docs/BRANCHING.md' },
  ]);
  assert.equal(s.files, 3);
  assert.equal(s.added, 115);
  assert.equal(s.deleted, 58);
  assert.equal(s.total, 173);
  assert.equal(s.generatedFiles, 1);
  assert.equal(s.generatedTotal, 150);
  assert.equal(s.reviewableFiles, 2);
  assert.equal(s.reviewableTotal, 23);
  assert.equal(s.generatedTotal + s.reviewableTotal, s.total);
});

test('empty diff summarizes to zero', () => {
  const s = summarize([]);
  assert.equal(s.total, 0);
  assert.equal(s.files, 0);
  assert.equal(s.generatedTotal, 0);
  assert.equal(s.reviewableTotal, 0);
});
