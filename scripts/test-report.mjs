// Test report summary: report.tsv -> JSON + human summary.
//
// report.tsv is written by tests/lib/report.sh (one row per shell suite).
// This script aggregates it so CI and the count gate (P0-3) share one parser.
//
// Usage:
//   node scripts/test-report.mjs [--report-dir DIR] [--json OUT] [--check]
//   --report-dir  directory containing report.tsv (default: ./artifacts)
//   --json        write the machine-readable summary to OUT (default: stdout)
//   --check       exit non-zero when the report is missing, unparseable, or
//                 contains zero suites (basic sanity; per-suite counts are
//                 enforced by scripts/check_test_counts.mjs in P0-3)
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let reportDir = path.resolve('artifacts');
let jsonOut = null;
let check = false;
for (let i = 0; i < args.length; i += 1) {
  if (args[i] === '--report-dir') ((reportDir = path.resolve(args[i + 1] ?? reportDir)), (i += 1));
  else if (args[i] === '--json') ((jsonOut = args[i + 1] ?? jsonOut), (i += 1));
  else if (args[i] === '--check') check = true;
  else if (args[i] === '--help' || args[i] === '-h') {
    console.log('usage: test-report.mjs [--report-dir DIR] [--json OUT] [--check]');
    process.exit(0);
  } else {
    console.error(`unknown argument: ${args[i]}`);
    process.exit(2);
  }
}

const tsvPath = path.join(reportDir, 'report.tsv');

function fail(msg) {
  console.error(`FAIL test-report: ${msg}`);
  process.exit(1);
}

if (!existsSync(tsvPath)) fail(`missing ${tsvPath} (run a test mode with reporting first)`);

const lines = readFileSync(tsvPath, 'utf8')
  .split('\n')
  .filter((l) => l.trim() !== '');
if (lines.length < 1) fail(`${tsvPath} is empty`);
const header = lines[0].split('\t');
const want = ['suite', 'status', 'pass', 'fail', 'total', 'duration_ms', 'shard'];
if (header.join('\t') !== want.join('\t')) fail(`${tsvPath} has an unexpected header: ${header.join(',')}`);

const num = (v) => {
  const n = Number.parseInt(v, 10);
  return Number.isFinite(n) && n >= 0 ? n : null;
};

const suites = [];
for (const line of lines.slice(1)) {
  const cols = line.split('\t');
  if (cols.length !== want.length) fail(`malformed row: ${line}`);
  const [suite, status, pass, failN, total, durationMs, shard] = cols;
  const p = num(pass);
  const f = num(failN);
  const t = num(total);
  const d = num(durationMs);
  if (p === null || f === null || t === null || d === null) fail(`non-numeric counters in row: ${line}`);
  if (!['pass', 'fail', 'missing'].includes(status)) fail(`unknown status in row: ${line}`);
  suites.push({ suite, status, pass: p, fail: f, total: t, duration_ms: d, shard });
}

const totals = {
  suites: suites.length,
  passed: suites.filter((s) => s.status === 'pass').length,
  failed: suites.filter((s) => s.status === 'fail').length,
  missing: suites.filter((s) => s.status === 'missing').length,
  pass: suites.reduce((a, s) => a + s.pass, 0),
  fail: suites.reduce((a, s) => a + s.fail, 0),
  total: suites.reduce((a, s) => a + s.total, 0),
  duration_ms: suites.reduce((a, s) => a + s.duration_ms, 0),
};

const summary = {
  generatedAt: new Date().toISOString(),
  reportDir,
  suites,
  totals,
};

if (check && suites.length === 0) fail('report contains zero suites');

const slowest = [...suites].sort((a, b) => b.duration_ms - a.duration_ms).slice(0, 10);
console.log(`suites=${totals.suites} passed=${totals.passed} failed=${totals.failed} missing=${totals.missing}`);
console.log(`assertions: pass=${totals.pass} fail=${totals.fail} total=${totals.total} (${totals.duration_ms}ms)`);
for (const s of slowest) console.log(`  slowest: ${s.suite} ${s.duration_ms}ms (${s.status})`);

if (jsonOut) writeFileSync(jsonOut, `${JSON.stringify(summary, null, 2)}\n`);
