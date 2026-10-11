import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, chmod } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

// Point the invoker at a deliberately slow stub, then import it.
const dir = await mkdtemp(path.join(tmpdir(), 'cobol-stub-'));
const stub = path.join(dir, 'slow-binary');
await writeFile(stub, '#!/bin/sh\nsleep 5\n');
await chmod(stub, 0o755);
process.env.COBOL_BIN = stub;

const { invoke, InvocationTimeout } = await import('../src/invoker.js');

test('a hung COBOL process is killed and reported as a timeout', async () => {
  await assert.rejects(
    () => invoke('CHECK_BALANCE', ['x@y.com'], { timeoutMs: 300 }),
    InvocationTimeout,
  );
});
