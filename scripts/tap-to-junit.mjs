// TAP to JUnit XML converter.
//
// Reads TAP (plan `1..N`, `ok`/`not ok` lines, `  # expected` / `  # got:`
// diagnostics, `# pass=` summary) from a file or stdin and writes one JUnit
// <testsuite>. It is a dumb converter: it never fails on test failures (a
// failing suite still produces a report), and a stream with zero tests yields
// a zero-test suite for the count gate (P0-3) to reject.
//
// Usage:
//   node scripts/tap-to-junit.mjs [--suite NAME] [--output FILE] [INPUT|-]
import { readFileSync, writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
let suite = 'suite';
let output = null;
let input = null;
for (let i = 0; i < args.length; i += 1) {
  if (args[i] === '--suite') ((suite = args[i + 1] ?? suite), (i += 1));
  else if (args[i] === '--output') ((output = args[i + 1] ?? output), (i += 1));
  else if (args[i] === '--help' || args[i] === '-h') {
    console.log('usage: tap-to-junit.mjs [--suite NAME] [--output FILE] [INPUT|-]');
    process.exit(0);
  } else if (!args[i].startsWith('--')) input = args[i];
  else {
    console.error(`unknown argument: ${args[i]}`);
    process.exit(2);
  }
}

let text;
if (!input || input === '-') {
  text = readFileSync(0, 'utf8');
} else {
  text = readFileSync(input, 'utf8');
}

const esc = (s) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;');

const tests = [];
let current = null;
let plan = null;
let summary = null;
for (const raw of text.split('\n')) {
  const line = raw.replace(/\r$/, '');
  let m = line.match(/^(not ok|ok)\s+(\d+)\s*(?:-\s*(.*))?$/);
  if (m) {
    if (current) tests.push(current);
    current = {
      ok: m[1] === 'ok',
      num: Number(m[2]),
      name: (m[3] ?? `test ${m[2]}`).trim() || `test ${m[2]}`,
      detail: [],
    };
    continue;
  }
  m = line.match(/^1\.\.(\d+)\s*$/);
  if (m) {
    plan = Number(m[1]);
    continue;
  }
  m = line.match(/^#\s*pass=(\d+)\s+fail=(\d+)\s+total=(\d+)/);
  if (m) {
    summary = { pass: Number(m[1]), fail: Number(m[2]), total: Number(m[3]) };
    continue;
  }
  // Diagnostics belong to the most recent test (`  # expected ...`).
  if (current && /^(\s+#|#)\s/.test(line)) {
    current.detail.push(line.trim());
  }
}
if (current) tests.push(current);

const failures = tests.filter((t) => !t.ok).length;
const total = summary ? summary.total : tests.length;

let xml = '<?xml version="1.0" encoding="utf-8"?>\n<testsuites>\n';
xml += `  <testsuite name="${esc(suite)}" tests="${total}" failures="${failures}" errors="0" skipped="0"`;
if (plan !== null) xml += ` plan="${plan}"`;
if (summary) xml += ` tap_pass="${summary.pass}" tap_fail="${summary.fail}" tap_total="${summary.total}"`;
xml += '>\n';
for (const t of tests) {
  xml += `    <testcase classname="${esc(suite)}" name="${esc(t.name)}"`;
  xml += ` assertions="1"`;
  xml += '>';
  if (!t.ok) {
    const msg = t.detail.length ? t.detail.join('\n') : 'assertion failed';
    xml += `<failure message="${esc(msg.slice(0, 500))}" type="tapFailure">${esc(msg)}</failure>`;
  }
  xml += '</testcase>\n';
}
xml += '  </testsuite>\n</testsuites>\n';

if (output) writeFileSync(output, xml);
else process.stdout.write(xml);
