// Coverage PR summary: appends the curated-COBOL + gateway coverage table to
// $GITHUB_STEP_SUMMARY. Extracted from the workflow so yamllint's line length
// and eslint both apply; behavior is identical to the former inline node -e.
import { appendFileSync, existsSync, readFileSync } from 'node:fs';

const summaryPath = process.env.COVERAGE_SUMMARY_JSON || 'coverage/summary.json';
const stepSummary = process.env.GITHUB_STEP_SUMMARY;
if (!existsSync(summaryPath)) {
  console.log('no coverage/summary.json (measurement skipped or failed early)');
  if (stepSummary) appendFileSync(stepSummary, 'no coverage/summary.json (measurement skipped or failed early)\n');
  process.exit(0);
}

const summary = JSON.parse(readFileSync(summaryPath, 'utf8'));
const base = {};
for (const line of readFileSync('tests/coverage_baseline.txt', 'utf8').split('\n')) {
  const t = line.trim();
  if (!t || t.startsWith('#')) continue;
  const [k, v] = t.split(/\s+/);
  base[k] = Number(v);
}
const cobolReport = JSON.parse(readFileSync('coverage/cobol.json', 'utf8'));
const rows = cobolReport.modules;
const copybooks = cobolReport.copybooks;
let copyBase;
if (existsSync('tests/coverage_copybook_baseline.txt')) {
  for (const line of readFileSync('tests/coverage_copybook_baseline.txt', 'utf8').split('\n')) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const [k, v] = t.split(/\s+/);
    if (k === 'copybooks') copyBase = Number(v);
  }
}
const modBase = new Map();
for (const line of readFileSync('tests/coverage_module_baseline.txt', 'utf8').split('\n')) {
  const t = line.trim();
  if (!t || t.startsWith('#')) continue;
  const [m, v] = t.split(/\s+/);
  modBase.set(m, Number(v));
}
const dropped = rows
  .filter((r) => modBase.has(r.module) && r.percent < modBase.get(r.module) - 1.0)
  .sort((a, b) => a.percent - modBase.get(a.module) - (b.percent - modBase.get(b.module)));
const d = (v, b) => `${v.toFixed(2)}% (baseline ${b.toFixed(2)}%, ${v - b >= 0 ? '+' : ''}${(v - b).toFixed(2)}pp)`;
const cobolMeasured = `${summary.cobol.percent.toFixed(2)}% covered of ${summary.cobol.executable} lines`;
const cobolBaseline =
  base.cobol_total === undefined
    ? 'floor 30% (total ratchet retired; per-module ratchet binds)'
    : `${d(summary.cobol.percent, base.cobol_total)} / floor 30%`;
const out = [
  '## Coverage (curated COBOL + gateway)',
  '',
  '| Suite | Measured | Baseline |',
  '|---|---|---|',
  `| COBOL curated | ${cobolMeasured} | ${cobolBaseline} |`,
];
if (copybooks) {
  const cbMeasured = `${copybooks.percent.toFixed(2)}% covered of ${copybooks.executable} lines (${Object.keys(copybooks.files ?? {}).length} files)`;
  const cbBaseline =
    copyBase === undefined ? 'no baseline yet (reported only)' : `${d(copybooks.percent, copyBase)} / ratchet 1.0pp`;
  out.push(`| COBOL copybooks (union) | ${cbMeasured} | ${cbBaseline} |`);
}
out.push(
  `| gateway lines | ${summary.gateway.lines.toFixed(2)}% | floor 80%, baseline ${base.gateway_lines}% |`,
  `| gateway branches | ${summary.gateway.branches.toFixed(2)}% | floor 70%, baseline ${base.gateway_branches}% |`,
  '',
);
if (dropped.length) {
  out.push('Modules below baseline (>1pp):');
  for (const r of dropped) out.push(`- ${r.module}: ${r.percent}% vs ${modBase.get(r.module)}%`);
  out.push('');
} else {
  out.push('No curated module dropped below its baseline.', '');
}
if (copybooks && (copyBase === undefined || copybooks.percent < copyBase)) {
  out.push('Copybook files (union, worst first):');
  for (const [f, r] of Object.entries(copybooks.files ?? {}).sort((a, b) => a[1].percent - b[1].percent)) {
    out.push(`- ${f}: ${r.percent}% (${r.covered}/${r.executable})`);
  }
  out.push('');
}
out.push('Full report: see the `coverage-pr` artifact on this run.');
if (stepSummary) appendFileSync(stepSummary, `${out.join('\n')}\n`);
else console.log(out.join('\n'));
