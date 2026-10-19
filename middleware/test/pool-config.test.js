// Worker-pool configuration and backpressure: every knob is validated (a
// malformed value refuses to boot instead of hanging requests), the waiting
// queue is bounded, a queued request is bounded by the timeout, and closing
// the pool fails whatever is still waiting instead of leaking it.
//
// Pooling is disabled in this file's process by default (COBOL_POOL_SIZE
// unset), so the shared pool stays null; the saturation cases build isolated
// Pool instances over a stub binary that never answers.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { writeFileSync, chmodSync, rmSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { poolConfig, assertPoolConfig, getPool, Pool } from '../src/pool.js';
import { InvocationTimeout, InvocationError, PoolSaturated } from '../src/errors.js';

const POOL_ENV = ['COBOL_POOL_SIZE', 'COBOL_POOL_PIPELINE', 'COBOL_POOL_TIMEOUT_MS', 'COBOL_POOL_QUEUE_MAX'];

function withEnv(values, fn) {
  const saved = {};
  for (const key of POOL_ENV) {
    saved[key] = process.env[key];
    if (values[key] === undefined) delete process.env[key];
    else process.env[key] = values[key];
  }
  try {
    return fn();
  } finally {
    for (const key of POOL_ENV) {
      if (saved[key] === undefined) delete process.env[key];
      else process.env[key] = saved[key];
    }
  }
}

// A binary that never writes a result line: stdin is accepted, stdout stays
// silent, so dispatched jobs sit in `pending` until their timeout. `exec`
// replaces the shell so killing the child really ends it (no orphan `sleep`
// holding the stdout pipe open).
const dir = mkdtempSync(path.join(tmpdir(), 'pool-config-'));
const STUB = path.join(dir, 'block.sh');
writeFileSync(STUB, '#!/bin/sh\nexec sleep 30\n');
chmodSync(STUB, 0o755);
const pools = [];
after(() => {
  for (const p of pools) p.close();
  rmSync(dir, { recursive: true, force: true });
});

function blockingPool(overrides = {}) {
  const pool = new Pool({ size: 1, timeoutMs: 150, pipeline: 1, queueMax: 1, binary: STUB, ...overrides });
  pools.push(pool);
  return pool;
}

// Capture a promise's settlement without awaiting it yet, so a rejection that
// lands before its assertion is not an unhandled rejection.
function settle(promise) {
  const state = { settled: false, error: null };
  promise.then(
    () => { state.settled = true; },
    (error) => { state.settled = true; state.error = error; },
  );
  return state;
}

const waitFor = async (state, ms = 3000) => {
  const deadline = Date.now() + ms;
  while (!state.settled && Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 10));
  }
  return state;
};

test('pool settings parse and bound the queue', () => {
  withEnv({ COBOL_POOL_SIZE: '2', COBOL_POOL_PIPELINE: '4' }, () => {
    assert.deepEqual(poolConfig(), { size: 2, pipeline: 4, timeoutMs: 5000, queueMax: 800 });
    assert.doesNotThrow(() => assertPoolConfig());
  });
  withEnv({ COBOL_POOL_SIZE: '0' }, () => {
    assert.deepEqual(poolConfig(), { size: 0 });
  });
  withEnv({ COBOL_POOL_SIZE: undefined }, () => {
    assert.deepEqual(poolConfig(), { size: 0 });
    assert.equal(getPool(), null, 'no pool in file mode');
  });
});

test('a malformed pool setting is refused instead of hanging requests', () => {
  const bad = [
    ['COBOL_POOL_SIZE', 'abc'],
    ['COBOL_POOL_SIZE', '-1'],
    ['COBOL_POOL_SIZE', '1.5'],
    ['COBOL_POOL_SIZE', '999'],
    ['COBOL_POOL_PIPELINE', '0'],
    ['COBOL_POOL_PIPELINE', 'nope'],
    ['COBOL_POOL_TIMEOUT_MS', '0'],
    ['COBOL_POOL_TIMEOUT_MS', '9999999'],
    ['COBOL_POOL_QUEUE_MAX', '0'],
  ];
  for (const [key, value] of bad) {
    withEnv({ COBOL_POOL_SIZE: '2', [key]: value }, () => {
      assert.throws(() => assertPoolConfig(), /must be/, `${key}=${value}`);
    });
  }
});

test('a full queue is rejected with backpressure', async () => {
  const pool = blockingPool();
  const inFlight = settle(pool.invoke('A')); // dispatched: pipeline is 1
  const queued = settle(pool.invoke('B')); // occupies the single queue slot
  await assert.rejects(() => pool.invoke('C'), (err) => err instanceof PoolSaturated);
  assert.equal(pool.stats().queued, 1, 'the queue stayed bounded');
  assert.equal(pool.stats().queueMax, 1);
  // The queued and in-flight jobs still fail on their own timeout.
  await waitFor(queued);
  await waitFor(inFlight);
  assert.ok(queued.error instanceof InvocationTimeout, `queued: ${queued.error}`);
  assert.ok(inFlight.error instanceof InvocationTimeout, `in flight: ${inFlight.error}`);
});

test('a request that waits too long is failed, not left hanging', async () => {
  const pool = blockingPool({ timeoutMs: 120 });
  const inFlight = settle(pool.invoke('A'));
  const started = Date.now();
  const queued = settle(pool.invoke('B'));
  await waitFor(queued);
  assert.ok(queued.error instanceof InvocationTimeout, `queued: ${queued.error}`);
  assert.match(queued.error.message, /queue wait/);
  assert.ok(Date.now() - started >= 100, 'waited for the budget before failing');
  await waitFor(inFlight);
  assert.ok(inFlight.error instanceof InvocationTimeout, `in flight: ${inFlight.error}`);
});

test('closing the pool fails whatever is still queued', async () => {
  const pool = blockingPool();
  const inFlight = settle(pool.invoke('A'));
  const queued = settle(pool.invoke('B'));
  pool.close();
  await waitFor(queued);
  assert.ok(queued.error instanceof InvocationError, `queued: ${queued.error}`);
  assert.match(queued.error.message, /closed/);
  await waitFor(inFlight);
  assert.ok(inFlight.settled, 'the in-flight job settles too');
  assert.equal(pool.stats().queued, 0);
  await assert.rejects(() => pool.invoke('C'), (err) => err instanceof InvocationError && /closed/.test(err.message));
});
