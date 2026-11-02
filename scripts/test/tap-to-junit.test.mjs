// Unit tests for scripts/tap-to-junit.mjs. No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const CONV = path.join(ROOT, 'scripts', 'tap-to-junit.mjs');

function convert(tap, args = []) {
  return execFileSync(process.execPath, [CONV, ...args], {
    input: tap,
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
  });
}

test('passing and failing tests map to testcase/failure', () => {
  const xml = convert(
    'ok 1 - first\nnot ok 2 - second\n  # expected /X/\n  # got:      Y\n1..2\n# pass=1 fail=1 total=2\n',
    ['--suite', 'demo'],
  );
  assert.match(xml, /<testsuite name="demo" tests="2" failures="1"/);
  assert.match(xml, /<testcase classname="demo" name="first"/);
  assert.match(xml, /<testcase classname="demo" name="second"/);
  assert.match(xml, /<failure message="# expected \/X\//);
  assert.match(xml, /# got: {6}Y/);
});

test('TAP plan and summary become testsuite attributes', () => {
  const xml = convert('ok 1 - a\n1..1\n# pass=1 fail=0 total=1\n');
  assert.match(xml, /tests="1" failures="0"/);
  assert.match(xml, /plan="1"/);
  assert.match(xml, /tap_pass="1" tap_fail="0" tap_total="1"/);
});

test('empty input yields a zero-test suite, not an error', () => {
  const xml = convert('nothing here\n', ['--suite', 'empty']);
  assert.match(xml, /tests="0" failures="0"/);
});

test('XML metacharacters in names are escaped', () => {
  const xml = convert('ok 1 - a<b>&"c"\nnot ok 2 - d\n', ['--suite', 's&t']);
  assert.ok(!xml.includes('a<b>'), 'raw < must not appear');
  assert.match(xml, /a&lt;b&gt;&amp;&quot;c&quot;/);
  assert.match(xml, /<testsuite name="s&amp;t"/);
});

test('diagnostics on a passing test are dropped, failures get a default message', () => {
  const xml = convert('ok 1 - one\n  # note: hello\nnot ok 2 - two\n', []);
  assert.ok(!xml.includes('note: hello'), 'passing-test diagnostics are not emitted');
  assert.match(xml, /<testcase classname="suite" name="two"[^>]*><failure message="assertion failed"/);
});

test('missing action lines without numbers are ignored gracefully', () => {
  const xml = convert('ok 1 - a\nsome log noise\nnot ok 2 - b\n');
  assert.match(xml, /tests="2" failures="1"/);
});
