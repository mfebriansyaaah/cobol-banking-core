// Shared helpers for scripts/test/*.test.mjs (P1-9).
// runGate spawns a gate script and captures output; parseSelectOutput parses
// the shell-evaluable SELECT_* assignments select_tests.mjs prints.
import { execFileSync } from 'node:child_process';
import { cpSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

export const REPO_ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
export const FIXTURE_MINI = path.join(REPO_ROOT, 'tests', 'fixtures', 'script-trees', 'mini');

/**
 * Copy the committed mini repo to a temp dir and return its path.
 * Register teardown with the caller's after(): cleanupFixture(root).
 */
export function makeFixtureRoot(prefix = 'gate-fixture-') {
  const dir = mkdtempSync(path.join(tmpdir(), prefix));
  cpSync(FIXTURE_MINI, dir, { recursive: true });
  return dir;
}

export function cleanupFixture(dir) {
  rmSync(dir, { recursive: true, force: true });
}

/**
 * Run a gate script with node. Returns { stdout, stderr, status }.
 * Never throws: assertion helpers decide what failure means.
 */
export function runGate(scriptRel, args = [], opts = {}) {
  const script = path.join(REPO_ROOT, scriptRel);
  try {
    const stdout = execFileSync(process.execPath, [script, ...args], {
      cwd: opts.cwd || REPO_ROOT,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: opts.timeout || 120000,
      env: { ...process.env, ...(opts.env || {}) },
    });
    return { stdout, stderr: '', status: 0 };
  } catch (e) {
    return {
      stdout: String((e && e.stdout) || ''),
      stderr: String((e && e.stderr) || e),
      status: typeof e?.status === 'number' ? e.status : 1,
    };
  }
}

/**
 * Parse `KEY="value"` lines into an object. Unknown lines are ignored so
 * human-readable progress lines do not break assertions.
 */
export function parseSelectOutput(text) {
  const out = {};
  for (const line of String(text).split('\n')) {
    const m = line.match(/^([A-Z_]+)="([\s\S]*)"$/);
    if (m) out[m[1]] = m[2];
  }
  return out;
}
