// Unit tests for scripts/ci/classify_changes.mjs (CI-011).
// Table-driven: every changed path maps to docs-only or full. Unknown
// paths and classifier errors fail safe to full (never skip).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { classifyFile, isDocsOnly } from '../ci/classify_changes.mjs';

const TOOL = new URL('../ci/classify_changes.mjs', import.meta.url).pathname;

// [changed files, expected docs_only]
const CASES = [
  [['docs/CI.md'], true],
  [['docs/CI.md', 'README.md', 'CHANGELOG.md', 'docs/TESTING.md'], true],
  [['.github/ISSUE_TEMPLATE/bug_report.md'], true],
  [['.github/pull_request_template.md'], true],
  [['.github/CODEOWNERS'], true],
  [['CONTRIBUTING.md', 'SECURITY.md', 'LICENSE'], true],
  [['middleware/src/routes/account.js'], false],
  [['middleware/test/gateway.test.js'], false],
  [['cobol/src/loan_core.cob'], false],
  [['tests/db/loan_db_tests.sh'], false],
  [['tests/README.md'], false],
  [['scripts/ci/coverage.sh'], false],
  [['.github/workflows/ci.yml'], false],
  [['database/schema.sql'], false],
  [['manifest/modules.json'], false],
  [['build.sh'], false],
  [['Makefile'], false],
  [['package.json'], false],
  [['middleware/package.json'], false],
  [['scripts/ci/weird-new-file.mjs'], false],
  [['totally-unknown.txt'], false],
  [['docs/CI.md', 'middleware/src/app.js'], false],
  [[], false],
];

for (const [files, expected] of CASES) {
  test(`isDocsOnly([${files.join(', ') || '<empty>'}]) === ${expected}`, () => {
    assert.equal(isDocsOnly(files), expected);
  });
}

test('classifyFile labels groups', () => {
  assert.equal(classifyFile('docs/CI.md'), 'docs');
  assert.equal(classifyFile('README.md'), 'docs');
  assert.equal(classifyFile('middleware/src/app.js'), 'full');
  assert.equal(classifyFile('tests/db/x.sh'), 'full');
  assert.equal(classifyFile('build.sh'), 'full');
  assert.equal(classifyFile('nope.txt'), 'unknown');
});

function runClassifier(files) {
  try {
    const out = execFileSync(process.execPath, [TOOL, '--stdin'], {
      input: files.join('\n') + '\n',
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: 30000,
    });
    return { status: 0, out: out.trim() };
  } catch (e) {
    return { status: typeof e?.status === 'number' ? e.status : 1, out: String(e?.stdout || '') };
  }
}

test('CLI prints docs_only=true for docs-only sets', () => {
  const r = runClassifier(['docs/CI.md', 'README.md']);
  assert.equal(r.status, 0);
  assert.match(r.out, /docs_only=true/);
});

test('CLI prints docs_only=false otherwise and never fails closed', () => {
  const r = runClassifier(['docs/CI.md', 'middleware/src/app.js']);
  assert.equal(r.status, 0);
  assert.match(r.out, /docs_only=false/);
  const empty = runClassifier([]);
  assert.equal(empty.status, 0);
  assert.match(empty.out, /docs_only=false/);
});
