// Documentation truth gate (audit P1-07): fail on known-bad claims that
// check_docs.mjs does not catch (generated numbers are gated, prose is not).
// No database, no build. Run via npm run test:scripts.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (p) => readFileSync(p, 'utf8');

test('branch protection docs match verified API state', () => {
  const gov = read('docs/GOVERNANCE.md');
  assert.doesNotMatch(gov, /branch protection .*not active/i);
  assert.match(gov, /branch protection .*active/i);
  const ci = read('docs/CI.md');
  assert.doesNotMatch(ci, /INACTIVE \(.*404 Branch not/);
  assert.match(ci, /ACTIVE/);
});

test('DB suite counts are current', () => {
  const testsReadme = read('tests/README.md');
  const testing = read('docs/TESTING.md');
  assert.doesNotMatch(testsReadme, /57 files plus/i);
  assert.doesNotMatch(testing, /with 58 suites/i);
  assert.match(testsReadme, /84/);
  assert.match(testing, /84 suites/);
});

test('route definitions use one metric', () => {
  const readme = read('README.md');
  const complexity = read('docs/COMPLEXITY_BASELINE.md');
  const m = complexity.match(/Gateway \| route definitions \| ([\d,]+)/);
  assert.ok(m, 'complexity baseline route count missing');
  const count = m[1].replace(/,/g, '');
  assert.match(readme, new RegExp(`Gateway route definitions \\| \\*\\*${count}\\*\\*`));
});

test('clone exclusion claim matches the export profile', () => {
  const card = read('docs/DATASET_CARD.md');
  assert.doesNotMatch(card, /excluded from `source`/i);
  assert.match(card, /excluded from the\s+`train`\s+profile/i);
});
