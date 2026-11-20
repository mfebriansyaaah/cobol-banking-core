// Unit tests for scripts/ci/classify_docker.mjs (cost workstream 1).
// Table-driven: every changed path maps to relevant or not. Empty and
// classifier errors fail safe to relevant (never skip the image build
// when we cannot tell).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { isDockerDefinitionChanged, isDockerRelevant } from '../ci/classify_docker.mjs';

const TOOL = new URL('../ci/classify_docker.mjs', import.meta.url).pathname;

// [changed files, expected relevance]
const CASES = [
  [['Dockerfile'], true],
  [['.dockerignore'], true],
  [['cobol/src/loan_core.cob'], true],
  [['cobol/c_lib/hash_lib.c'], true],
  [['cobol/copy/loan-copy.cpy'], true],
  [['middleware/src/routes/account.js'], true],
  [['middleware/src/app.js'], true],
  [['middleware/package.json'], true],
  [['middleware/package-lock.json'], true],
  [['middleware/contract/openapi.yaml'], true],
  [['middleware/core-client/pool.js'], true],
  [['middleware/adapters/x.js'], true],
  [['middleware/services/y.js'], true],
  [['middleware/workers/z.js'], true],
  [['middleware/telemetry/t.js'], true],
  [['build.sh'], true],
  [['cobol/Makefile'], true],
  [['scripts/ci/install_gnucobol.sh'], true],
  [['docs/CI.md'], false],
  [['README.md'], false],
  [['tests/db/loan_db_tests.sh'], false],
  [['tests/README.md'], false],
  [['middleware/test/gateway.test.js'], false],
  [['.github/workflows/ci.yml'], false],
  [['scripts/ci/coverage.sh'], false],
  [['scripts/check_docs.mjs'], false],
  [['database/schema.sql'], false],
  [['database/migrations/0001_x.sql'], false],
  [['manifest/modules.json'], false],
  [['package.json'], false],
  [['totally-unknown.txt'], false],
  [['tools/deploy.sh'], false],
  [[], true],
  [['   '], true],
];

for (const [files, expected] of CASES) {
  test(`isDockerRelevant([${files.join(', ')}]) === ${expected}`, () => {
    assert.equal(isDockerRelevant(files), expected);
  });
}

test('CLI prints docker_relevant=true for Dockerfile via --stdin', () => {
  const out = execFileSync(process.execPath, [TOOL, '--stdin'], { input: 'Dockerfile\n', encoding: 'utf8' });
  assert.match(out, /^docker_relevant=true/m);
  assert.match(out, /^docker_definition=true/m);
});

test('CLI prints docker_relevant=false for docs-only via --stdin', () => {
  const out = execFileSync(process.execPath, [TOOL, '--stdin'], { input: 'docs/CI.md\n', encoding: 'utf8' });
  assert.match(out, /^docker_relevant=false/m);
  assert.match(out, /^docker_definition=false/m);
});

test('CLI prints docker_relevant=true for empty input via --stdin', () => {
  const out = execFileSync(process.execPath, [TOOL, '--stdin'], { input: '\n', encoding: 'utf8' });
  assert.match(out, /^docker_relevant=true/m);
  assert.match(out, /^docker_definition=true/m);
});

test('input source changes are image-relevant but not definition changes', () => {
  assert.equal(isDockerDefinitionChanged(['cobol/src/loan_core.cob']), false);
  assert.equal(isDockerDefinitionChanged(['middleware/src/app.js']), false);
  assert.equal(isDockerDefinitionChanged(['Dockerfile']), true);
  assert.equal(isDockerDefinitionChanged(['middleware/package-lock.json']), true);
  assert.equal(isDockerDefinitionChanged([]), true);
});
