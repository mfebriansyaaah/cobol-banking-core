// TRIM/RESULT copybook adoption pins (DRY-00A).
//
// TRIM-ALL/TRIM-VALUE live in common_trim.cpy, TRIM-RESULT-LEN in
// common_result.cpy. Every module that PERFORMs one of these must COPY the
// matching file, except the documented INLINE_* sets below (shrunk by the
// DRY wave: DRY-01 converts the 22 TRIM clones, DRY-02 the wallet TRIM
// clones, DRY-03 the auth TRIM-RESULT clones).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const COPY = path.join(ROOT, 'cobol', 'copy');
const modules = readdirSync(SRC)
  .filter((f) => f.endsWith('.cob'))
  .map((f) => f.replace(/\.cob$/, ''))
  .sort();
const srcOf = (m) => readFileSync(path.join(SRC, `${m}.cob`), 'utf8');
const copyOf = (f) => readFileSync(path.join(COPY, f), 'utf8');

// Exception history: DRY-01 emptied the 22 TRIM clones, DRY-02 the wallet
// clones, DRY-03 the auth TRIM-RESULT clones. Shrink again in the PR that
// converts a module.
const INLINE_TRIM_OK = new Set(['gl_core', 'ref_engine']);
const INLINE_RESULT_OK = new Set();

const performs = (src, name) => new RegExp(`^\\s*PERFORM ${name}\\s*$`, 'm').test(src);

test('copybooks define the shared paragraphs', () => {
  assert.match(copyOf('common_trim.cpy'), /^\s{7}TRIM-ALL\./m);
  assert.match(copyOf('common_trim.cpy'), /^\s{7}TRIM-VALUE\./m);
  assert.match(copyOf('common_result.cpy'), /^\s{7}TRIM-RESULT-LEN\./m);
});

test('no inline TRIM-VALUE outside documented exceptions', () => {
  for (const m of modules) {
    if (INLINE_TRIM_OK.has(m)) continue;
    assert.doesNotMatch(srcOf(m), /^\s{7,8}TRIM-VALUE\./m, `${m}: inline TRIM-VALUE`);
  }
});

test('no inline TRIM-RESULT-LEN outside documented exceptions', () => {
  for (const m of modules) {
    if (INLINE_RESULT_OK.has(m)) continue;
    assert.doesNotMatch(srcOf(m), /^\s{7,8}TRIM-RESULT-LEN\./m, `${m}: inline TRIM-RESULT-LEN`);
  }
});

test('INLINE_TRIM_OK holds exactly the 2 documented exceptions', () => {
  assert.equal(INLINE_TRIM_OK.size, 2);
});

test('every TRIM-ALL performer resolves to a COPY or an exception', () => {
  for (const m of modules) {
    const src = srcOf(m);
    if (!performs(src, 'TRIM-ALL')) continue;
    assert.ok(
      src.includes('COPY "common_trim.cpy"') || src.includes('COPY "wallet_entry.cpy"') || INLINE_TRIM_OK.has(m),
      `${m}: PERFORM TRIM-ALL without common_trim/wallet_entry COPY`,
    );
  }
});
