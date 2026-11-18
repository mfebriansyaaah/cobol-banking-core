// Unit tests for the JS complexity ratchet key/rendering helpers.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { entryKey, readBaseline, renderBaseline } from '../check_js_complexity.mjs';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

test('named functions key by file + name; anonymous functions by line', () => {
  assert.equal(
    entryKey('middleware/x.js', 42, "Async function 'deliverRow' has a complexity of 20. Maximum allowed is 15."),
    'middleware/x.js|deliverRow',
  );
  assert.equal(
    entryKey('middleware/x.js', 42, 'Arrow function has a complexity of 17. Maximum allowed is 15.'),
    'middleware/x.js|@42',
  );
});

test('baseline round-trips and ignores comments/blank lines', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'js-complexity-'));
  try {
    mkdirSync(path.join(dir, 'tests'), { recursive: true });
    writeFileSync(
      path.join(dir, 'tests', 'js_complexity_baseline.txt'),
      '# comment\nmiddleware/a.js|foo|18\n\nmiddleware/b.js|@7|16\n',
    );
    const parsed = readBaseline(dir);
    assert.equal(parsed.get('middleware/a.js|foo'), 18);
    assert.equal(parsed.get('middleware/b.js|@7'), 16);
    const text = renderBaseline([{ file: 'middleware/a.js', key: 'middleware/a.js|foo', complexity: 18 }]);
    assert.match(text, /middleware\/a\.js\|foo\|18/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
