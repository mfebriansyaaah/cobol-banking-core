import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { BINARY } from './binary.js';
import { InvocationTimeout, InvocationError } from './errors.js';
import { getPool } from './pool.js';

export { BINARY, InvocationTimeout, InvocationError };

// File mode (ADR-0001): the binary reads input.txt / writes output.txt in its
// own working directory. Used by default, and by all shell suites.
async function fileInvoke(action, params = [], opts = {}) {
  const timeoutMs = opts.timeoutMs ?? 5000;
  const dir = await mkdtemp(path.join(tmpdir(), 'cobol-gw-'));
  try {
    const line = [action, ...params].slice(0, 7).join('|') + '\n';
    await writeFile(path.join(dir, 'input.txt'), line);

    await new Promise((resolve, reject) => {
      const child = spawn(BINARY, [], { cwd: dir });
      const timer = setTimeout(() => {
        child.kill('SIGKILL');
        reject(new InvocationTimeout(`COBOL call exceeded ${timeoutMs}ms`));
      }, timeoutMs);
      child.on('error', (err) => {
        clearTimeout(timer);
        reject(new InvocationError(err.message));
      });
      child.on('close', () => {
        clearTimeout(timer);
        resolve();
      });
    });

    const out = await readFile(path.join(dir, 'output.txt'), 'utf8');
    // COBOL writes the result in 500-char records; join them back into one line
    // (each record is space-padded, so trailing spaces per line are stripped).
    return out
      .split('\n')
      .map((line) => line.replace(/\s+$/, ''))
      .join('');
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

/**
 * Run one COBOL action and return its raw result line.
 * Uses the worker pool when COBOL_POOL_SIZE is set, else file mode (ADR-0001).
 * @param {string} action
 * @param {string[]} params up to four pipe-safe parameter values
 * @param {{timeoutMs?: number}} [opts]
 */
export async function invoke(action, params = [], opts = {}) {
  const pool = getPool();
  if (pool) return pool.invoke(action, params, opts);
  return fileInvoke(action, params, opts);
}
