// CI step summary for test reports. Reads artifacts/run-all.json (shell
// suites) and JUnit XMLs (gateway suites) and writes a Markdown summary to
// $GITHUB_STEP_SUMMARY (or stdout when unset, e.g. local runs).
//
// Informational only: always exits 0. Enforcement lives in P0-3
// (scripts/check_test_counts.mjs). Run with `if: always()` so failing runs
// still report what broke.
//
// Usage:
//   node scripts/ci/summary.mjs [--report-dir DIR]
import { existsSync, readdirSync, readFileSync, appendFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let reportDir = 'artifacts';
for (let i = 0; i < args.length; i += 1) {
  if (args[i] === '--report-dir') reportDir = args[i + 1] ?? reportDir, i += 1;
  else if (args[i] === '--help' || args[i] === '-h') {
    console.log('usage: summary.mjs [--report-dir DIR]');
    process.exit(0);
  }
}

const out = [];
const esc = (s) => String(s).replace(/\|/g, '\\|');

let shell = null;
const jsonPath = path.join(reportDir, 'run-all.json');
if (existsSync(jsonPath)) {
  try {
    shell = JSON.parse(readFileSync(jsonPath, 'utf8'));
  } catch {
    shell = null;
  }
}

// Collect JUnit files recursively (gateway :junit suites write them next to
// run-all.json; endpoint_smoke uses TEST_REPORT_DIR).
const junitFiles = [];
const walk = (dir) => {
  if (!existsSync(dir)) return;
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.xml')) junitFiles.push(p);
  }
};
walk(reportDir);

const attr = (tag, name, src) => {
  const m = src.match(new RegExp(`<${tag}[^>]*\\s${name}="([^"]*)"`));
  return m ? m[1] : null;
};

let junit = { files: 0, tests: 0, failures: 0, errors: 0, failed: [] };
for (const f of junitFiles) {
  let src = '';
  try {
    src = readFileSync(f, 'utf8');
  } catch {
    continue;
  }
  if (!src.includes('<testsuite')) continue;
  junit.files += 1;
  const num = (v) => {
    const n = Number.parseInt(v ?? '0', 10);
    return Number.isFinite(n) ? n : 0;
  };
  const countTag = (tag) => (src.match(new RegExp(`<${tag}[\\s>]`, 'g')) || []).length;
  if (/<testsuite[\s>]/.test(src)) {
    // tap-to-junit.mjs style: one <testsuite> wrapper with counters.
    junit.tests += num(attr('testsuite', 'tests', src)) || num(attr('testsuites', 'tests', src));
    junit.failures += num(attr('testsuite', 'failures', src));
    junit.errors += num(attr('testsuite', 'errors', src));
  } else {
    // Node --test-reporter=junit style: bare <testcase> list under
    // <testsuites>, counts only in trailing comments.
    junit.tests += countTag('testcase');
    junit.failures += countTag('failure');
    junit.errors += countTag('error');
  }
  // Failed test names: <testcase ...> blocks containing <failure|<error.
  const blocks = src.match(/<testcase[\s\S]*?<\/testcase>|<testcase[^>]*\/>/g) || [];
  for (const b of blocks) {
    if (/<(failure|error)[\s>]/.test(b)) {
      const cls = attr('testcase', 'classname', b) || path.basename(f);
      const name = attr('testcase', 'name', b) || '(unnamed)';
      if (junit.failed.length < 20) junit.failed.push(`${cls} :: ${name}`);
    }
  }
}

out.push('## Test report');
if (shell) {
  const t = shell.totals;
  out.push('');
  out.push(`shell suites: ${t.suites} (passed ${t.passed}, failed ${t.failed}, missing ${t.missing})`);
  out.push(`shell assertions: pass ${t.pass} / fail ${t.fail} / total ${t.total} (${t.duration_ms}ms)`);
  const slowest = [...shell.suites].sort((a, b) => b.duration_ms - a.duration_ms).slice(0, 10);
  out.push('');
  out.push('| slowest suite | status | assertions | duration |');
  out.push('|---|---|---:|---:|');
  for (const s of slowest) out.push(`| ${esc(s.suite)} | ${s.status} | ${s.total} | ${s.duration_ms}ms |`);
  const bad = shell.suites.filter((s) => s.status !== 'pass').slice(0, 20);
  if (bad.length) {
    out.push('');
    out.push(`non-passing shell suites (${bad.length}):`);
    for (const s of bad) out.push(`- ${esc(s.suite)} (${s.status}, pass ${s.pass}/fail ${s.fail}/total ${s.total})`);
  }
} else {
  out.push('');
  out.push(`no shell report found at ${jsonPath}`);
}
if (junit.files) {
  out.push('');
  out.push(`gateway JUnit: ${junit.files} file(s), ${junit.tests} tests, ${junit.failures} failures, ${junit.errors} errors`);
  if (junit.failed.length) {
    out.push('');
    out.push(`failed gateway tests (first ${junit.failed.length}):`);
    for (const n of junit.failed) out.push(`- ${esc(n)}`);
  }
} else {
  out.push('');
  out.push('no gateway JUnit XML found (expected junit-*.xml next to run-all.json)');
}
out.push('');

const text = `${out.join('\n')}\n`;
const dest = process.env.GITHUB_STEP_SUMMARY;
if (dest) {
  try {
    appendFileSync(dest, text);
  } catch {
    process.stdout.write(text);
  }
} else {
  process.stdout.write(text);
}
