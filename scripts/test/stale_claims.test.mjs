// Unit tests for scripts/ci/stale_claims.mjs (CI-006).
// Every known-bad numeric/wording claim must be caught, unless the line is
// explicitly marked historical.
import { test } from 'node:test';
import assert from 'assert/strict';
import { findStaleClaims } from '../ci/stale_claims.mjs';

const f = (text, filePath = 'docs/CI.md') => [{ path: filePath, text }];

test('stale fleet counts are caught', () => {
  assert.equal(findStaleClaims(f('the fleet has 274 DB suites')).length, 1);
  assert.equal(findStaleClaims(f('273 files plus schema')).length, 1);
  assert.equal(findStaleClaims(f('all 2,780 route actions')).length, 1);
  assert.equal(findStaleClaims(f('Four shards split ~537 suites')).length, 1);
  assert.equal(findStaleClaims(f('pins all 24 curated modules')).length, 1);
});

test('wrong required-check name is caught in docs', () => {
  const hits = findStaleClaims(f('required checks db-aggregate and lint'));
  assert.equal(hits.length, 1);
  assert.match(hits[0].rule, /check-name/);
});

test('retired README claims are caught', () => {
  assert.equal(findStaleClaims(f('No hosted CI', 'README.md')).length, 1);
  assert.equal(findStaleClaims(f('All 11 roadmap items complete', 'README.md')).length, 1);
});

test('lines marked historical are skipped, not rewritten', () => {
  assert.deepEqual(findStaleClaims(f('historical: 274 DB suites (2026-11-04)')), []);
  assert.deepEqual(findStaleClaims(f('HISTORICAL record: 2,780 actions')), []);
});

test('current numbers do not trip the gate', () => {
  assert.deepEqual(findStaleClaims(f('the fleet has 46 DB suites')), []);
  assert.deepEqual(findStaleClaims(f('548 route definitions')), []);
  assert.equal(findStaleClaims(f('required checks db aggregate and coverage')).length, 0);
});
