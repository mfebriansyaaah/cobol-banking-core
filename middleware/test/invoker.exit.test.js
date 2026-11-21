import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, chmod } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

// Point the invoker at a stub that crashes, then import it.
const dir = await mkdtemp(path.join(tmpdir(), 'cobol-stub-'));
const stub = path.join(dir, 'crash-binary');
await writeFile(stub, '#!/bin/sh\nexit 3\n');
await chmod(stub, 0o755);
process.env.COBOL_BIN = stub;

const { invoke, InvocationError } = await import('../src/invoker.js');

test('a COBOL process that exits non-zero is reported as unavailable, never success', async () => {
  await assert.rejects(() => invoke('PING', [], { timeoutMs: 3000 }), InvocationError);
});
