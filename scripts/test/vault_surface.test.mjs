// Vault surface lock: document adapters (storage/scan/retention) are
// operator-grade library calls (vault suite + retention drill), never
// request-path code. KTP material is never persisted and OCR runs by
// reference, so document intake has no gateway endpoint by design (see
// "No HTTP surface" in docs/runbooks/vault-kms.md). Wiring one into
// middleware/src must fail here until that section is revised.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'middleware', 'src');

function listJs(dir) {
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...listJs(p));
    else if (p.endsWith('.js')) out.push(p);
  }
  return out;
}

test('no gateway source calls document vault operations', () => {
  // server.js may import the boot assertion (assertVaultConfig); the
  // operational calls (PUT/DELETE/scan/sweep) must stay out of src.
  const offenders = listJs(SRC).filter((f) => {
    const src = readFileSync(f, 'utf8');
    return /\b(putObject|deleteObject|scanBuffer|sweepRetention)\b/.test(src);
  });
  assert.deepEqual(
    offenders.map((f) => path.relative(ROOT, f)),
    [],
    'document vault operations must stay out of the request path',
  );
});

test('the runbook states the no-HTTP-surface design', () => {
  const runbook = readFileSync(path.join(ROOT, 'docs', 'runbooks', 'vault-kms.md'), 'utf8');
  assert.match(runbook, /No HTTP surface \(by design\)/);
});
