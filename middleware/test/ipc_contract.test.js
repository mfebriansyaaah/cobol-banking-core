// IPC contract tests: exercise the COBOL core directly through the gateway's
// invoker (file mode) and assert the raw result-line protocol. These guard
// the pipe-delimited contract independently of the HTTP layer.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { invoke } from '../src/invoker.js';
import { seedUser, requireSeed, runSql } from './support.js';

const ADMIN = `ipc_admin_${Date.now()}@test.com`;

test('IPC contract: PING round-trips a single result line', async () => {
  const raw = await invoke('PING', []);
  assert.equal(raw, 'SUCCESS|PONG');
});

test('IPC contract: missing action is reported', async () => {
  const raw = await invoke('', []);
  assert.equal(raw, 'ERROR|MISSING_ACTION');
});

test('IPC contract: unknown action is reported', async () => {
  const raw = await invoke('NO_SUCH_ACTION_XYZ', []);
  assert.equal(raw, 'ERROR|INVALID_ACTION');
});

test('IPC contract: a 500-char output record is joined back into one line', async () => {
  requireSeed(seedUser(ADMIN, 'SUPER_ADMIN'), 'seed an admin for IPC contract');
  after(() => runSql(`DELETE FROM users WHERE email='${ADMIN}'`));

  const raw = await invoke('LIST_USERS', ['100', '0', ADMIN, '']);
  assert.ok(raw.startsWith('SUCCESS|LIST_DONE|'), 'expected LIST_DONE');
  // The response must be a single logical line, not 500-char chunks.
  assert.ok(!raw.includes('\n'), 'joined result must not contain newlines');
  assert.ok(raw.length > 500, 'long output must exceed one 500-char record');
});
