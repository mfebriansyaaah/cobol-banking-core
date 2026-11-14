// Family working-storage copybook pins (DRY-05). No database, no build.
//
// wallet_ws_common / loan_schedule_ws_common / report_ws_common /
// import_ws_common hold the byte-identical WS declaration runs shared by
// each family. Every host COPYs its family file and must not redeclare the
// shared 01s inline; every copybook var must be used by at least one host.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const COPY = path.join(ROOT, 'cobol', 'copy');

const FAMILIES = {
  'wallet_ws_common.cpy': [
    'wallet_dispute_core',
    'wallet_hold_core',
    'wallet_recon_core',
    'wallet_reversal_core',
    'wallet_statement_core',
  ],
  'loan_schedule_ws_common.cpy': [
    'loan_schedule_core',
    'loan_schedule_lifecycle_core',
    'loan_schedule_posting_core',
    'loan_schedule_report_core',
  ],
  'report_ws_common.cpy': ['report_core', 'report_run_core'],
  'import_ws_common.cpy': ['import_core', 'import_row_core'],
};

const srcOf = (m) => readFileSync(path.join(SRC, `${m}.cob`), 'utf8');
const copyOf = (f) => readFileSync(path.join(COPY, f), 'utf8');
const declsOf = (text) => [...text.matchAll(/^\s+01\s+([A-Z][A-Z0-9-]+)\s+PIC/gm)].map((m) => m[1]);

test('every family host COPYs its shared working-storage', () => {
  for (const [cpy, hosts] of Object.entries(FAMILIES)) {
    for (const m of hosts) {
      assert.match(srcOf(m), new RegExp(`COPY "${cpy}"`), `${m}: missing ${cpy} COPY`);
    }
  }
});

test('no host redeclares the shared 01s inline', () => {
  for (const [cpy, hosts] of Object.entries(FAMILIES)) {
    for (const name of declsOf(copyOf(cpy))) {
      for (const m of hosts) {
        assert.doesNotMatch(
          srcOf(m),
          new RegExp(`^\\s+01\\s+${name}\\s+PIC`, 'm'),
          `${m}: inline duplicate of shared ${name}`,
        );
      }
    }
  }
});

test('every shared WS var is used by at least one host', () => {
  // References may live in host code or in another copybook the host COPYs
  // (e.g. F-QUOTE is consumed by wallet_entry.cpy's VALIDATE-INPUT). An 01
  // that owns referenced 88-levels counts as used via its children (it must
  // exist to declare them) — same rule as check_copybooks.
  const allCopy = readdirSync(COPY)
    .filter((f) => f.endsWith('.cpy'))
    .map((f) => readFileSync(path.join(COPY, f), 'utf8'))
    .join('\n');
  const childrenOf = (cpyText, name) => {
    const kids = [];
    let mine = false;
    for (const line of cpyText.split('\n')) {
      let m = line.match(/^\s+01\s+([A-Z][A-Z0-9-]+)\s/);
      if (m) mine = m[1] === name;
      m = line.match(/^\s+88\s+([A-Z][A-Z0-9-]+)\s/);
      if (m && mine) kids.push(m[1]);
    }
    return kids;
  };
  for (const [cpy, hosts] of Object.entries(FAMILIES)) {
    const combined = hosts.map(srcOf).join('\n') + '\n' + allCopy;
    const cpyText = copyOf(cpy);
    for (const name of declsOf(cpyText)) {
      const hits = (re) => (combined.match(re) || []).length;
      const uses = hits(new RegExp(`\\b${name}\\b`, 'g'));
      const decls = hosts.filter((m) => new RegExp(`^\\s+01\\s+${name}\\s`, 'm').test(srcOf(m))).length + 1; // +1: the copybook definition
      const childUse = childrenOf(cpyText, name).some((c) => hits(new RegExp(`\\b${c}\\b`, 'g')) > 0);
      assert.ok(uses > decls || childUse, `${cpy}: ${name} never referenced`);
    }
  }
});
