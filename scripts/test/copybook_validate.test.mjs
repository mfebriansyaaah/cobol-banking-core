// VALIDATE copybook pins (maint-03b, extended maint-07). No database, no build.
//
// VALIDATE-ALL/VALIDATE-INPUT vary by input variable (WS-TRIM-IN vs
// WS-CHECK), rejected charset (F-SEMI or not), and control flow — so the
// two WS-TRIM-IN 6-param shapes are shared in two files, plus the wallet
// WS-CHECK+SEMI early-exit shape in a third (cobc validates every
// paragraph of an included copybook, so one file per declaration
// footprint):
//   common_validate_all.cpy:  VALIDATE-ALL + VALIDATE-INPUT
//   common_validate_semi.cpy: VALIDATE-ALL + VALIDATE-INPUT-SEMI
//   wallet_entry.cpy:         VALIDATE-ALL + VALIDATE-INPUT (WS-CHECK,
//                             SEMI charset, early-exit; shared by
//                             wallet_core and wallet_transfer_core)
// (SEMI hosts PERFORM the plain VALIDATE-ALL name; each host COPYs exactly
// one file, so each sees exactly one definition.)
// Documented inline exceptions (keep their paragraphs, do not convert):
//   auth×5 (4-param WS-CHECK, NL/CR charset — different security property),
//   gl_core + import×2 (action-dependent VALIDATE-LINES branches),
//   ref_engine + user_core (WS-CHECK shapes),
//   wallet×5 (early-exit control flow; wallet_core converted to
//   wallet_entry.cpy in maint-07).
// Universal invariant: no module outside INLINE_OK may define these
// paragraphs inline; every PERFORM must resolve (inline exception or the
// matching COPY).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC_DIR = path.join(ROOT, 'cobol', 'src');
const COPY_DIR = path.join(ROOT, 'cobol', 'copy');

const INLINE_OK = new Set([
  'auth_core',
  'auth_mfa_core',
  'auth_ops_core',
  'auth_recovery_core',
  'auth_review_core',
  'gl_core',
  'import_core',
  'import_row_core',
  'ref_engine',
  'user_core',
  'wallet_dispute_core',
  'wallet_hold_core',
  'wallet_recon_core',
  'wallet_reversal_core',
  'wallet_statement_core',
]);

// Paragraphs that must never be defined inline outside INLINE_OK. Plain
// VALIDATE-ALL/VALIDATE-INPUT come from either shared file; the SEMI-only
// INPUT name must not be defined inline anywhere (it never existed).
const SHARED_INLINE_BANNED = ['VALIDATE-ALL', 'VALIDATE-INPUT', 'VALIDATE-INPUT-SEMI'];

const modules = readdirSync(SRC_DIR)
  .filter((f) => f.endsWith('.cob') && f !== 'main_logic.cob')
  .map((f) => f.replace(/\.cob$/, ''))
  .sort();
const srcOf = (module) => readFileSync(path.join(SRC_DIR, `${module}.cob`), 'utf8');
const copyOf = (file) => readFileSync(path.join(COPY_DIR, file), 'utf8');
const inlineParas = (src) =>
  [...src.matchAll(/^ {7,8}(VALIDATE-ALL(?:-SEMI)?|VALIDATE-INPUT(?:-SEMI)?)\.$/gm)].map((m) => m[1]);
const performs = (src, name) => new RegExp(`^\\s*PERFORM ${name}\\s*$`, 'm').test(src);
const copies = (src) =>
  [...src.matchAll(/COPY "(common_validate(?:_all|_semi)?\.cpy|wallet_entry\.cpy)"/g)].map((m) => m[1]);

test('shared files define the two pairs, generic, one definition each', () => {
  const all = copyOf('common_validate_all.cpy');
  assert.match(all, /^ {7}VALIDATE-ALL\.$/m, 'all-file must define VALIDATE-ALL');
  assert.match(all, /^ {7}VALIDATE-INPUT\.$/m, 'all-file must define VALIDATE-INPUT');
  assert.doesNotMatch(all, /VALIDATE-INPUT-SEMI/, 'all-file must not mention the SEMI name');
  const semi = copyOf('common_validate_semi.cpy');
  assert.match(semi, /^ {7}VALIDATE-ALL\.$/m, 'semi-file must define VALIDATE-ALL (plain name)');
  assert.match(semi, /^ {7}VALIDATE-INPUT-SEMI\.$/m, 'semi-file must define VALIDATE-INPUT-SEMI');
  assert.doesNotMatch(semi, /MOVE "[A-Z0-9_]+" TO WS-/m, 'shared paragraphs take no module constants');
});

test('no module outside INLINE_OK defines shared paragraphs inline', () => {
  const offenders = [];
  for (const module of modules) {
    if (INLINE_OK.has(module)) continue;
    const found = inlineParas(srcOf(module)).filter((p) => SHARED_INLINE_BANNED.includes(p));
    if (found.length) offenders.push(`${module}: ${found.join(',')}`);
  }
  assert.deepEqual(offenders, []);
});

test('every module COPYs at most one validate file, and PERFORMs resolve', () => {
  for (const module of modules) {
    const src = srcOf(module);
    const files = [...new Set(copies(src).filter((f) => f !== 'common_validate.cpy'))];
    assert.ok(files.length <= 1, `${module}: COPYs two validate files (${files.join(',')})`);
    const provides = new Set();
    if (files.includes('common_validate_all.cpy')) {
      provides.add('VALIDATE-ALL').add('VALIDATE-INPUT');
    }
    if (files.includes('common_validate_semi.cpy')) {
      provides.add('VALIDATE-ALL').add('VALIDATE-INPUT-SEMI');
    }
    if (files.includes('wallet_entry.cpy')) {
      provides.add('VALIDATE-ALL').add('VALIDATE-INPUT');
    }
    for (const name of ['VALIDATE-ALL', 'VALIDATE-INPUT', 'VALIDATE-INPUT-SEMI']) {
      if (!performs(src, name)) continue;
      assert.ok(
        provides.has(name) || inlineParas(src).includes(name),
        `${module}: PERFORM ${name} resolves nowhere (no inline paragraph, no matching COPY)`,
      );
    }
  }
});

test('INLINE_OK holds exactly the 15 documented exceptions', () => {
  assert.equal(INLINE_OK.size, 15);
});
