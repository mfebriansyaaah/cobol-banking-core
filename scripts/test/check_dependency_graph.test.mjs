// Unit tests for scripts/check_dependency_graph.mjs (ADR-0006). No DB, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_dependency_graph.mjs');

test('dependency graph holds on the real tree', () => {
  const out = execFileSync('node', [GATE, ROOT], { encoding: 'utf8' });
  assert.match(out, /OK: dependency graph holds/);
});

test('canonical leaves exist (ADR-0006)', async () => {
  const { existsSync } = await import('node:fs');
  assert.equal(existsSync(path.join(ROOT, 'middleware', 'core-client', 'invoker.js')), true);
  assert.equal(existsSync(path.join(ROOT, 'middleware', 'core-client', 'pool.js')), true);
  assert.equal(existsSync(path.join(ROOT, 'middleware', 'core-client', 'result.js')), true);
  assert.equal(existsSync(path.join(ROOT, 'middleware', 'telemetry', 'observability.js')), true);
  assert.equal(existsSync(path.join(ROOT, 'middleware', 'adapters', 'signals.js')), true);
  assert.equal(existsSync(path.join(ROOT, 'middleware', 'adapters', 'otp.js')), true);
  assert.equal(existsSync(path.join(ROOT, 'middleware', 'adapters', 'guards.js')), true);
});

test('no reverse imports (services/workers do not reach src)', async () => {
  const { readFileSync } = await import('node:fs');
  const mailer = readFileSync(path.join(ROOT, 'middleware', 'services', 'mailer.js'), 'utf8');
  assert.doesNotMatch(mailer, /from\s+['"]\.\.\/src\//);
  const resilience = readFileSync(
    path.join(ROOT, 'middleware', 'services', 'integrations', 'resilience.js'),
    'utf8',
  );
  assert.doesNotMatch(resilience, /from\s+['"]\.\.\/\.\.\/src\//);
  const outbox = readFileSync(path.join(ROOT, 'middleware', 'workers', 'outbox.js'), 'utf8');
  assert.doesNotMatch(outbox, /from\s+['"]\.\.\/src\//);
});

test('src transport does not import services directly (except composition root)', async () => {
  const { readFileSync } = await import('node:fs');
  const app = readFileSync(path.join(ROOT, 'middleware', 'src', 'app.js'), 'utf8');
  assert.doesNotMatch(app, /from\s+['"]\.\.\/services\//);
  assert.match(app, /from\s+['"]\.\.\/adapters\//);
});
