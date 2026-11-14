// Unit tests for the ADR-0006 follow-up gates: transaction ownership,
// COBOL call graph, and field sizes. No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

for (const [gate, pattern] of [
  ['check_transaction_ownership.mjs', /OK: transaction ownership holds/],
  ['check_cobol_field_sizes.mjs', /OK: field sizes hold/],
  ['check_cobol_call_graph.mjs', /OK: call graph holds/],
]) {
  test(`${gate} holds on the real tree`, () => {
    const out = execFileSync('node', [path.join(ROOT, 'scripts', gate), ROOT], { encoding: 'utf8' });
    assert.match(out, pattern);
  });
}

test('call-graph registry is in sync and lists the known orchestrator edges', async () => {
  const { readFileSync } = await import('node:fs');
  const doc = JSON.parse(readFileSync(path.join(ROOT, 'manifest', 'cobol_calls.json'), 'utf8'));
  assert.equal(doc.count, doc.edges.length);
  const keys = new Set(doc.edges.map((e) => `${e.from} -> ${e.to}`));
  // Orchestrator edges the architecture review approved (ADR-0006):
  // wallet transfer→payment policy check (relocated wallet_core→
  // payment_core in maint-07; the transfer module owns the JOIN),
  // instruction→wallet posting, EOD jobs→domain modules, password
  // delegate→auth.
  for (const e of [
    'wallet_transfer_core -> payment_core',
    'wallet_transfer_core -> fee_core',
    'payment_instruction_core -> wallet_core',
    'eod_jobs_core -> user_core',
    'eod_jobs_core -> statement_core',
    'eod_jobs_core -> wallet_recon_core',
    'auth_password_core -> auth_core',
  ]) {
    assert.ok(keys.has(e), `registry must list ${e}`);
  }
});

test('copybook-resident CALLs belong to every including module', async () => {
  const { readdirSync, readFileSync } = await import('node:fs');
  const doc = JSON.parse(readFileSync(path.join(ROOT, 'manifest', 'cobol_calls.json'), 'utf8'));
  const keys = new Set(doc.edges.map((e) => `${e.from} -> ${e.to}`));
  // 15B2 moved deposit's gl_core CALL into deposit_lifecycle.cpy; the edge
  // must stay attributed to deposit_core or the transaction seam hides.
  assert.ok(keys.has('deposit_core -> gl_core'), 'deposit_core -> gl_core must survive the extraction');
  // auth_password_logic.cpy CALLs hashlen_core for every host that COPYs it.
  // DRY-03 removed the dead COPYs from the four split modules; only
  // auth_core still hosts the password logic.
  const hosts = readdirSync(path.join(ROOT, 'cobol', 'src'))
    .filter((f) => f.endsWith('.cob'))
    .filter((f) => /COPY "auth_password_logic\.cpy"/.test(readFileSync(path.join(ROOT, 'cobol', 'src', f), 'utf8')))
    .map((f) => f.replace(/\.cob$/, ''));
  assert.deepEqual(hosts, ['auth_core'], `only auth_core hosts password logic, got ${hosts.join(', ')}`);
  for (const host of hosts) {
    assert.ok(keys.has(`${host} -> hashlen_core`), `${host} -> hashlen_core must be registered`);
  }
});

test('no module declares an oversized query buffer', async () => {
  const { readdirSync, readFileSync } = await import('node:fs');
  for (const f of readdirSync(path.join(ROOT, 'cobol', 'src')).filter((x) => x.endsWith('.cob'))) {
    const src = readFileSync(path.join(ROOT, 'cobol', 'src', f), 'utf8');
    for (const m of src.matchAll(/01\s+WS-PREP-SQL\s+PIC\s+X\((\d+)\)/g)) {
      assert.ok(Number(m[1]) <= 1024, `${f}: WS-PREP-SQL X(${m[1]})`);
    }
  }
});
