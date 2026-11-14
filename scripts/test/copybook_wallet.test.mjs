// Wallet shared-copybook pins (DRY-02). No database, no build.
//
// wallet_entry.cpy (VALIDATE-ALL/INPUT, TRIM-ALL/TRIM-ONE) is shared by all
// 7 wallet modules; wallet_audit.cpy (AUDIT-DENIED) by the 6 that authorize;
// wallet_caps.cpy (CHECK-CAP-DIGITS/CHARS) by the 5 that enforce caps.
// No wallet module may define these paragraphs inline.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const COPY = path.join(ROOT, 'cobol', 'copy');

const ENTRY_HOSTS = [
  'wallet_core',
  'wallet_dispute_core',
  'wallet_hold_core',
  'wallet_recon_core',
  'wallet_reversal_core',
  'wallet_statement_core',
  'wallet_transfer_core',
];
const AUDIT_HOSTS = ENTRY_HOSTS.filter((m) => m !== 'wallet_transfer_core');
const CAPS_HOSTS = [
  'wallet_dispute_core',
  'wallet_hold_core',
  'wallet_recon_core',
  'wallet_statement_core',
  'wallet_transfer_core',
];

const srcOf = (m) => readFileSync(path.join(SRC, `${m}.cob`), 'utf8');
const defines = (src, name) => new RegExp(`^\\s{7,8}${name}\\.`, 'm').test(src);

test('wallet copybooks define the shared paragraphs', () => {
  const entry = readFileSync(path.join(COPY, 'wallet_entry.cpy'), 'utf8');
  assert.match(entry, /^\s{7,8}VALIDATE-ALL\./m);
  assert.match(entry, /^\s{7,8}VALIDATE-INPUT\./m);
  assert.match(entry, /^\s{7,8}TRIM-ALL\./m);
  assert.match(entry, /^\s{7,8}TRIM-ONE\./m);
  const audit = readFileSync(path.join(COPY, 'wallet_audit.cpy'), 'utf8');
  assert.match(audit, /^\s{7,8}AUDIT-DENIED\./m);
  assert.match(audit, /PERFORM RECORD-AUTHZ-DENIED/);
  const caps = readFileSync(path.join(COPY, 'wallet_caps.cpy'), 'utf8');
  assert.match(caps, /^\s{7,8}CHECK-CAP-DIGITS\./m);
  assert.match(caps, /^\s{7,8}CHECK-CAP-CHARS\./m);
});

test('every wallet entry host COPYs wallet_entry.cpy', () => {
  for (const m of ENTRY_HOSTS) {
    assert.match(srcOf(m), /COPY "wallet_entry\.cpy"/, `${m}: missing wallet_entry COPY`);
  }
});

test('no wallet module defines entry paragraphs inline', () => {
  for (const m of ENTRY_HOSTS) {
    const src = srcOf(m);
    for (const name of ['VALIDATE-ALL', 'VALIDATE-INPUT', 'TRIM-ALL', 'TRIM-ONE']) {
      assert.doesNotMatch(src, new RegExp(`^\\s{7,8}${name}\\.`, 'm'), `${m}: inline ${name}`);
    }
  }
});

test('every wallet audit host COPYs wallet_audit.cpy, none defines it inline', () => {
  for (const m of AUDIT_HOSTS) {
    const src = srcOf(m);
    assert.match(src, /COPY "wallet_audit\.cpy"/, `${m}: missing wallet_audit COPY`);
    assert.doesNotMatch(src, /^\s{7,8}AUDIT-DENIED\./m, `${m}: inline AUDIT-DENIED`);
  }
});

test('every wallet caps host COPYs wallet_caps.cpy, none defines them inline', () => {
  for (const m of CAPS_HOSTS) {
    const src = srcOf(m);
    assert.match(src, /COPY "wallet_caps\.cpy"/, `${m}: missing wallet_caps COPY`);
    assert.doesNotMatch(src, /^\s{7,8}CHECK-CAP-DIGITS\./m, `${m}: inline CHECK-CAP-DIGITS`);
    assert.doesNotMatch(src, /^\s{7,8}CHECK-CAP-CHARS\./m, `${m}: inline CHECK-CAP-CHARS`);
  }
});
