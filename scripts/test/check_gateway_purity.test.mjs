// Unit tests for scripts/check_gateway_purity.mjs. No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_gateway_purity.mjs');

test('gateway purity holds on the real tree', () => {
  const out = execFileSync('node', [GATE, ROOT], { encoding: 'utf8' });
  assert.match(out, /OK: gateway purity holds/);
});

test('responseMappers has no direct invoke/auth imports', async () => {
  const { readFileSync } = await import('node:fs');
  const src = readFileSync(path.join(ROOT, 'middleware', 'src', 'responseMappers.js'), 'utf8');
  assert.doesNotMatch(src, /from\s+['"]\.\/invoker\.js['"]/);
  assert.doesNotMatch(src, /from\s+['"]\.\/auth\.js['"]/);
});

test('derivations compute without invoking COBOL', async () => {
  const { readFileSync } = await import('node:fs');
  const src = readFileSync(path.join(ROOT, 'middleware', 'src', 'derivations.js'), 'utf8');
  assert.doesNotMatch(src, /from\s+['"]\.\/invoker\.js['"]/);
  assert.doesNotMatch(src, /\b(SELECT|INSERT INTO|UPDATE \w+ SET|DELETE FROM)\b/i);
});

test('relocated service paths do not exist inside src', async () => {
  const { existsSync } = await import('node:fs');
  assert.equal(existsSync(path.join(ROOT, 'middleware', 'src', 'integrations')), false);
  assert.equal(existsSync(path.join(ROOT, 'middleware', 'src', 'mailer.js')), false);
  assert.equal(existsSync(path.join(ROOT, 'middleware', 'src', 'outbox_worker.js')), false);
});
