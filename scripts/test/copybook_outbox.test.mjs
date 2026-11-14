// Outbox + result copybook adoption pins (DRY-03). No database, no build.
//
// common_outbox.cpy (ENQUEUE-NOTIFICATION) is shared by auth_core,
// auth_recovery_core and user_core; common_result.cpy (TRIM-RESULT-LEN)
// by the five auth modules that still trim results.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'cobol', 'src');
const COPY = path.join(ROOT, 'cobol', 'copy');
const srcOf = (m) => readFileSync(path.join(SRC, `${m}.cob`), 'utf8');

test('common_outbox.cpy defines ENQUEUE-NOTIFICATION with the outbox insert', () => {
  const cpy = readFileSync(path.join(COPY, 'common_outbox.cpy'), 'utf8');
  assert.match(cpy, /^\s{7,8}ENQUEUE-NOTIFICATION\./m);
  assert.match(cpy, /INSERT INTO notification_outbox/);
});

test('auth_core, auth_recovery and user_core COPY common_outbox, none defines it inline', () => {
  for (const m of ['auth_core', 'auth_recovery_core', 'user_core']) {
    const src = srcOf(m);
    assert.match(src, /COPY "common_outbox\.cpy"/, `${m}: missing common_outbox COPY`);
    assert.doesNotMatch(src, /^\s{7,8}ENQUEUE-NOTIFICATION\./m, `${m}: inline ENQUEUE-NOTIFICATION`);
  }
});

test('result-trimming auth modules COPY common_result, none defines it inline', () => {
  for (const m of ['auth_core', 'auth_ops_core', 'auth_recovery_core', 'auth_review_core', 'auth_session_core']) {
    const src = srcOf(m);
    assert.match(src, /COPY "common_result\.cpy"/, `${m}: missing common_result COPY`);
    assert.doesNotMatch(src, /^\s{7,8}TRIM-RESULT-LEN\./m, `${m}: inline TRIM-RESULT-LEN`);
  }
});
