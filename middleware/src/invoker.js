import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// The binary reads input.txt and writes output.txt relative to its working
// directory. Each call therefore runs in its own temp directory (ADR-0001).
export const BINARY =
  process.env.COBOL_BIN ||
  path.resolve(__dirname, '../../cobol/bin/main_logic');

export class InvocationTimeout extends Error {}
export class InvocationError extends Error {}

/**
 * Run one COBOL action and return its raw result line.
 * @param {string} action
 * @param {string[]} params up to four pipe-safe parameter values
 * @param {{timeoutMs?: number}} [opts]
 */
export async function invoke(action, params = [], opts = {}) {
  const timeoutMs = opts.timeoutMs ?? 5000;
  const dir = await mkdtemp(path.join(tmpdir(), 'cobol-gw-'));
  try {
    const line = [action, ...params].slice(0, 5).join('|') + '\n';
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
    return out.split('\n')[0].trim();
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}
