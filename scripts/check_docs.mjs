// Documentation drift and link checker.
//
// - README generated stats must match scripts/docs_stats.mjs.
// - README generated test table must match scripts/build_test_table.mjs.
// - docs/COMPLEXITY_BASELINE.md must match scripts/audit_complexity.mjs.
// - Required community/runbook files must exist.
// - Local Markdown links must resolve.
// - At least 80% of manifest modules must be referenced from docs/README.
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { collect, renderReadmeBlock, ROOT } from './docs_stats.mjs';
import { renderTestTable } from './build_test_table.mjs';
import { baselineRows, audit, parseBaselineMarkdown } from './audit_complexity.mjs';
import { findStaleClaims } from './ci/stale_claims.mjs';

const REQUIRED = [
  'README.md',
  'CONTRIBUTING.md',
  'SECURITY.md',
  'CHANGELOG.md',
  'docs/STATUS.md',
  'docs/MODULE_INDEX.md',
  'docs/COVERAGE.md',
  'docs/GOVERNANCE.md',
  'docs/runbooks/secret-rotation.md',
  '.github/pull_request_template.md',
  '.github/ISSUE_TEMPLATE/bug_report.md',
  '.github/ISSUE_TEMPLATE/feature_request.md',
];

const errors = [];

const walkMarkdown = (dir) => {
  if (!existsSync(dir)) return [];
  const out = [];
  for (const entry of readdirSync(dir)) {
    const full = path.join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) out.push(...walkMarkdown(full));
    else if (entry.endsWith('.md')) out.push(full);
  }
  return out;
};

const stripCodeFences = (text) => text.replace(/```[\s\S]*?```/g, '');

const checkLinks = (file) => {
  const text = stripCodeFences(readFileSync(file, 'utf8'));
  const re = /\]\(([^)\s]+)\)/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    const raw = m[1];
    if (/^(https?:|mailto:|#)/.test(raw)) continue;
    const target = raw.split('#')[0];
    if (!target) continue;
    const resolved = target.startsWith('/') ? path.join(ROOT, target) : path.resolve(path.dirname(file), target);
    if (!existsSync(resolved)) {
      errors.push(`${path.relative(ROOT, file)}: missing link target ${raw}`);
    }
  }
};

for (const rel of REQUIRED) {
  if (!existsSync(path.join(ROOT, rel))) errors.push(`missing required file: ${rel}`);
}

const stats = collect();
const readme = readFileSync(path.join(ROOT, 'README.md'), 'utf8');
const begin = '<!-- BEGIN GENERATED STATS -->';
const end = '<!-- END GENERATED STATS -->';
const start = readme.indexOf(begin);
const stop = readme.indexOf(end);
if (start < 0 || stop < start) {
  errors.push('README.md is missing the generated stats markers');
} else {
  const actual = readme.slice(start, stop + end.length);
  const expected = renderReadmeBlock(stats);
  if (actual !== expected) {
    errors.push('README generated stats are stale; run `node scripts/docs_stats.mjs --write`');
  }
}

for (const phrase of ['No hosted CI', 'All 11 roadmap items complete']) {
  if (readme.includes(phrase)) errors.push(`README.md still contains stale claim: "${phrase}"`);
}

{
  // Generated test table (maint-12a): rendered from tests/baseline_counts.txt.
  const begin = '<!-- BEGIN GENERATED TEST TABLE -->';
  const end = '<!-- END GENERATED TEST TABLE -->';
  const start = readme.indexOf(begin);
  const stop = readme.indexOf(end);
  if (start < 0 || stop < start) {
    errors.push('README.md is missing the generated test-table markers');
  } else {
    const actual = readme.slice(start, stop + end.length);
    const expected = renderTestTable(ROOT).trimEnd();
    if (actual.trimEnd() !== expected) {
      errors.push('README generated test table is stale; run `node scripts/build_test_table.mjs --write`');
    }
  }
}

{
  // Complexity baseline (maint-12a): docs/COMPLEXITY_BASELINE.md must match
  // a fresh audit (same comparison as `audit_complexity.mjs --check`).
  const docPath = path.join(ROOT, 'docs', 'COMPLEXITY_BASELINE.md');
  if (!existsSync(docPath)) {
    errors.push('docs/COMPLEXITY_BASELINE.md is missing; run `node scripts/audit_complexity.mjs --write`');
  } else {
    const recorded = parseBaselineMarkdown(readFileSync(docPath, 'utf8'));
    for (const [area, metric, value] of baselineRows(audit(ROOT))) {
      const key = `${area} | ${metric}`;
      if (!recorded.has(key)) errors.push(`COMPLEXITY_BASELINE.md is missing metric: ${key}`);
      else if (recorded.get(key) !== value) {
        errors.push(
          `COMPLEXITY_BASELINE.md is stale (${key}: recorded ${recorded.get(key)}, tree has ${value}); run \`node scripts/audit_complexity.mjs --write\` after review`,
        );
      }
    }
  }
}

const markdownFiles = [
  path.join(ROOT, 'README.md'),
  path.join(ROOT, 'CONTRIBUTING.md'),
  path.join(ROOT, 'SECURITY.md'),
  path.join(ROOT, 'CHANGELOG.md'),
  ...walkMarkdown(path.join(ROOT, 'docs')),
].filter((f) => existsSync(f));
markdownFiles.forEach(checkLinks);

// Stale volatile numbers and wrong required-check names (CI-006). Historical
// R0 evidence lines containing "historical" are skipped by the scanner.
// tests/README.md carries fleet counts too, so it is scanned here even
// though link/reach checks stay on markdownFiles.
const staleExtra = [path.join(ROOT, 'tests', 'README.md')].filter((f) => existsSync(f));
const staleFiles = [...markdownFiles, ...staleExtra].map((f) => ({
  path: path.relative(ROOT, f),
  text: readFileSync(f, 'utf8'),
}));
for (const hit of findStaleClaims(staleFiles)) {
  errors.push(`${hit.path}:${hit.line}: stale claim (${hit.rule}): ${hit.message}`);
}

const allDocs = markdownFiles.map((f) => readFileSync(f, 'utf8')).join('\n');
const reach = stats.modules.filter((m) => allDocs.includes(m.module)).length;
const reachPct = stats.modules.length ? (100 * reach) / stats.modules.length : 0;
if (reachPct < 80) {
  errors.push(`documentation reach is ${reachPct.toFixed(1)}% (need >=80%); regenerate docs/MODULE_INDEX.md`);
}

if (errors.length) {
  console.error('DOCUMENTATION CHECK FAILED:');
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}

console.log(
  `OK: docs stats current; ${markdownFiles.length} markdown file(s); links valid; module reach ${reach}/${stats.modules.length} (${reachPct.toFixed(1)}%)`,
);
