// Unit tests for the per-file fixture namespace helpers in support.js.
// Pure: no database required. cleanupNamespace() is only asserted for its
// return contract against an unmatchable namespace (it deletes zero rows when
// the database is reachable, returns false when mysql is absent).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { testNamespace, uniqueEmail, cleanupNamespace } from './support.js';

function withPatched(patches, fn) {
  const saved = new Map();
  for (const [obj, key, value] of patches) {
    saved.set([obj, key], obj[key]);
    obj[key] = value;
  }
  try {
    return fn();
  } finally {
    for (const [[obj, key], value] of saved) obj[key] = value;
  }
}

test('testNamespace emits a dash-delimited lowercase namespace', () => {
  const ns = testNamespace('gw');
  assert.match(ns, /^[a-z0-9-]{1,12}-[a-z0-9]+-[a-z0-9]{3}$/);
  assert.ok(!ns.includes('_'), 'no underscores: LIKE-safe without backslash escaping');
  assert.ok(ns.startsWith('gw-'), 'namespaces carry their file tag');
});

test('TEST_RUN_ID becomes the shared stamp for one-run residue checks', () => {
  const prev = process.env.TEST_RUN_ID;
  process.env.TEST_RUN_ID = 'tAbC123';
  try {
    const a = testNamespace('gw');
    const b = testNamespace('ep');
    assert.ok(a.includes('-tabc123-'), `run id is embedded lowercased: ${a}`);
    assert.ok(b.includes('-tabc123-'), `shared across files: ${b}`);
    assert.notEqual(a, b, 'file tag and rand keep files distinct');
  } finally {
    if (prev === undefined) delete process.env.TEST_RUN_ID;
    else process.env.TEST_RUN_ID = prev;
  }
});

test('namespaces are deterministic under patched clock and rand', () => {
  const prev = process.env.TEST_RUN_ID;
  delete process.env.TEST_RUN_ID;
  try {
    const [a, b] = withPatched(
      [
        [Date, 'now', () => 1700000000000],
        [Math, 'random', () => 0],
      ],
      () => [testNamespace('gw'), testNamespace('gw')],
    );
    assert.equal(a, b, 'same ms + same rand draw the same stamp');
    assert.match(a, /^gw-[a-z0-9]+-000$/, `rand segment is the patched draw: ${a}`);
  } finally {
    if (prev === undefined) delete process.env.TEST_RUN_ID;
    else process.env.TEST_RUN_ID = prev;
  }
});

test('uniqueEmail sanitizes names and stays inside the email column', () => {
  assert.equal(uniqueEmail('gw-abc-000', 'Weird Name!'), 'gw-abc-000-weirdname@test.com');
  assert.equal(uniqueEmail('gw-abc-000'), 'gw-abc-000-u@test.com');
  const prev = process.env.TEST_RUN_ID;
  process.env.TEST_RUN_ID = `t${'9'.repeat(100)}`;
  try {
    const em = uniqueEmail(testNamespace('gateway-file-tag-is-long'), 'a-very-long-fixture-name-here');
    assert.ok(em.endsWith('@test.com'));
    assert.ok(em.length <= 100, `fits users.email(100): ${em.length} chars`);
  } finally {
    if (prev === undefined) delete process.env.TEST_RUN_ID;
    else process.env.TEST_RUN_ID = prev;
  }
});

test('cleanupNamespace honors its return contract on an unmatchable namespace', () => {
  // Matches nothing by construction; deletes zero rows when the database is
  // reachable, returns false when mysql is absent. Either way it must not throw.
  const ns = 'no-such-ns-zzz-qqq-000';
  const ok = cleanupNamespace(ns);
  assert.equal(typeof ok, 'boolean');
});
