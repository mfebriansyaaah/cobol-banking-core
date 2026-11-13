// Deposit lifecycle extraction pins (maint-15B1). No database, no build.
//
// ACTION-OPEN and ACTION-MATURE move out of deposit_core.cob into
// deposit_lifecycle.cpy together with their claim/delete wrappers. The
// copybook is included by deposit_core (same compiled module), so the
// actions keep their single transaction, working storage, and audit
// helpers. 15B2 extracts ACTION-CLOSE the same way.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC_DIR = path.join(ROOT, 'cobol', 'src');
const SRC = path.join(SRC_DIR, 'deposit_core.cob');
const COPY = path.join(ROOT, 'cobol', 'copy', 'deposit_lifecycle.cpy');

const MOVED = ['ACTION-OPEN', 'ACTION-MATURE', 'CLAIM-OPEN-REQUEST', 'DELETE-OPEN-REQUEST'];
const STILL_INLINE = ['ACTION-CLOSE', 'CLAIM-CLOSE-REQUEST', 'DELETE-CLOSE-REQUEST'];

const src = () => readFileSync(SRC, 'utf8');
const copy = () => readFileSync(COPY, 'utf8');
const defines = (text, name) => new RegExp(`^ {7,8}${name}\\.$`, 'm').test(text);

test('deposit_lifecycle.cpy defines the open/mature lifecycle', () => {
  const cpy = copy();
  for (const name of MOVED) {
    assert.ok(defines(cpy, name), `copybook must define ${name}`);
  }
  // The actions keep their transaction ownership and idempotency calls.
  assert.match(cpy, /CALL "SQL_BEGIN"/, 'copybook must keep the funding transaction');
  assert.match(cpy, /PERFORM IDEM-CLAIM/, 'copybook must keep the claim path');
  assert.match(cpy, /PERFORM IDEM-LINK|PERFORM LINK-OPEN-REQUEST/, 'copybook must keep the open/target linkage');
});

test('deposit_core COPYs the lifecycle and keeps no inline copy', () => {
  const s = src();
  assert.match(s, /COPY "deposit_lifecycle\.cpy"/, 'deposit_core must COPY deposit_lifecycle.cpy');
  for (const name of MOVED) {
    assert.ok(!defines(s, name), `deposit_core: inline ${name} must be gone`);
  }
  // 15B2 scope: the close lifecycle stays inline for now.
  for (const name of STILL_INLINE) {
    assert.ok(defines(s, name), `deposit_core must still define ${name} (15B2 scope)`);
  }
});

test('copybook stays single-consumer and dispatch stays in the host', () => {
  const cpy = copy();
  assert.doesNotMatch(cpy, /WHEN\s+"DEP_(OPEN|CLOSE|MATURE)"/, 'dispatch stays in the host MAIN-LOGIC');
  // Single-host copybook: host-specific constants (the ALLOW-ADMIN denied
  // target) are part of the relocated text. A second consumer must be
  // reviewed for them first, so pin the consumer set.
  const consumers = readdirSync(SRC_DIR)
    .filter((f) => f.endsWith('.cob'))
    .filter((f) => /COPY "deposit_lifecycle\.cpy"/.test(readFileSync(path.join(SRC_DIR, f), 'utf8')));
  assert.deepEqual(consumers, ['deposit_core.cob'], 'only the deposit owner may include the lifecycle copybook');
});
