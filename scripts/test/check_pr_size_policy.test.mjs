// Unit tests for scripts/check_pr_size_policy.mjs (maint-00).
// No database, no build. Builds minimal policy trees in temp dirs.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { checkPolicy } from '../check_pr_size_policy.mjs';

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeRoot({ oldCeiling = false, missingTemplateField = null } = {}) {
  const d = mkdtempSync(path.join(tmpdir(), 'prsizepol-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'docs'), { recursive: true });
  mkdirSync(path.join(d, '.github'), { recursive: true });
  const branching = oldCeiling
    ? 'Maximum diff: 3500 changed lines excluding generated fixtures/docs.\n'
    : 'Prefer PRs under 1.500 changed lines. Larger changes require a recorded exception. There is no fixed line ceiling.\n';
  const governance = oldCeiling
    ? 'Prefer under 500 changed lines (ceiling 3500 with a recorded exception).\n'
    : 'Prefer under 1.500 changed lines; >1.500 requires a recorded exception.\n';
  const contributing = oldCeiling
    ? 'within the 3500-line ceiling (recorded exception path).\n'
    : 'prefer under 1.500 changed lines. Larger PRs require a recorded exception.\n';
  let template = 'Size tier: S\nTotal diff: 100\nSemantic diff: 90\nException: none\n';
  if (missingTemplateField) {
    template = template
      .split('\n')
      .filter((l) => !l.startsWith(missingTemplateField))
      .join('\n');
  }
  writeFileSync(path.join(d, 'docs', 'BRANCHING.md'), branching);
  writeFileSync(path.join(d, 'docs', 'GOVERNANCE.md'), governance);
  writeFileSync(path.join(d, 'CONTRIBUTING.md'), contributing);
  writeFileSync(path.join(d, '.github', 'pull_request_template.md'), template);
  return d;
}

test('new policy tree passes', () => {
  assert.deepEqual(checkPolicy(makeRoot()), []);
});

test('old fixed ceiling is caught in all three docs', () => {
  const errors = checkPolicy(makeRoot({ oldCeiling: true }));
  assert.ok(
    errors.some((e) => e.startsWith('docs/BRANCHING.md')),
    errors.join('\n'),
  );
  assert.ok(
    errors.some((e) => e.startsWith('docs/GOVERNANCE.md')),
    errors.join('\n'),
  );
  assert.ok(
    errors.some((e) => e.startsWith('CONTRIBUTING.md')),
    errors.join('\n'),
  );
});

test('missing PR template field is caught', () => {
  const errors = checkPolicy(makeRoot({ missingTemplateField: 'Size tier' }));
  assert.equal(errors.length, 1);
  assert.match(errors[0], /Size tier/);
});

test('missing file is reported, not thrown', () => {
  const d = mkdtempSync(path.join(tmpdir(), 'prsizepol-empty-'));
  dirs.push(d);
  const errors = checkPolicy(d);
  assert.equal(errors.length, 4);
});
