// IPC contract over the worker pool (serve mode): same assertions as the
// file-mode contract, ensuring the framing survives stdin/stdout pipelining.
process.env.COBOL_POOL_SIZE = '2';
process.env.COBOL_POOL_PIPELINE = '2';

import { test, after } from 'node:test';
import assert from 'node:assert/strict';

const { invoke, resetPool } = await (async () => {
  const invoker = await import('../src/invoker.js');
  return { invoke: invoker.invoke, resetPool: (await import('../src/pool.js')).resetPool };
})();

const { seedUser, requireSeed, runSql } = await import('./support.js');

const ADMIN = `ipc_pool_admin_${Date.now()}@test.com`;

after(() => {
  runSql(`DELETE FROM users WHERE email='${ADMIN}'`);
  resetPool();
});

test('IPC contract (pool): PING round-trips a single result line', async () => {
  const raw = await invoke('PING', []);
  assert.equal(raw, 'SUCCESS|PONG');
});

test('IPC contract (pool): long output is joined back into one line', async () => {
  requireSeed(seedUser(ADMIN, 'SUPER_ADMIN'), 'seed an admin for IPC contract (pool)');
  const raw = await invoke('LIST_USERS', ['100', '0', ADMIN, '']);
  assert.ok(raw.startsWith('SUCCESS|LIST_DONE|'));
  assert.ok(!raw.includes('\n'));
  assert.ok(raw.length > 500);
});
