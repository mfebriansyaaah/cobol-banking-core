// README test table generator (maint-12a): the manual per-suite table
// drifted (stale date, stale counts, missing suites), so the table is now
// rendered from tests/baseline_counts.txt. Usage:
//   node scripts/build_test_table.mjs [--write] [root]
// --write replaces the section between the TEST-TABLE markers in README.md.
// check_docs.mjs fails when the section is missing or stale.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const args = process.argv.slice(2);
let root = '.';
let write = false;
for (const a of args) {
  if (a === '--write') write = true;
  else if (a === '--help' || a === '-h') {
    console.log('usage: build_test_table.mjs [--write] [root]');
    process.exit(0);
  } else if (!a.startsWith('--')) root = a;
  else {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  }
}
root = path.resolve(root);

const BEGIN = '<!-- BEGIN GENERATED TEST TABLE -->';
const END = '<!-- END GENERATED TEST TABLE -->';

export function loadBaselineCounts(rootDir) {
  const rows = [];
  for (const line of readFileSync(path.join(rootDir, 'tests', 'baseline_counts.txt'), 'utf8').split('\n')) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const eq = t.indexOf('=');
    if (eq < 0) continue;
    rows.push({ key: t.slice(0, eq), count: t.slice(eq + 1) });
  }
  return rows;
}

export function suiteTarget(key) {
  if (key === 'cobol_table_tests') return 'tests/cobol/cases/*.cases';
  if (key === 'gateway_tests') return 'middleware/test/*.js';
  if (key.startsWith('db_') && key.endsWith('_tests')) {
    return `tests/db/${key.slice(3, -'_tests'.length)}_db_tests.sh`;
  }
  return null;
}

export function renderTestTable(rootDir) {
  const rows = loadBaselineCounts(rootDir);
  let total = 0;
  const out = [BEGIN, '| Suite file | Assertions |', '| --- | ---: |'];
  for (const { key, count } of rows) {
    const target = suiteTarget(key);
    const n = Number(count);
    if (Number.isFinite(n)) total += n;
    const cell = target ? `\`${target}\`` : `\`${key}\``;
    out.push(`| ${cell} | ${count} |`);
  }
  out.push(`| **Total** | **${total}** |`);
  out.push(END);
  return `${out.join('\n')}\n`;
}

export function writeTestTable(rootDir = root) {
  const readmePath = path.join(rootDir, 'README.md');
  const readme = readFileSync(readmePath, 'utf8');
  const start = readme.indexOf(BEGIN);
  const end = readme.indexOf(END);
  if (start < 0 || end < 0 || end < start) {
    throw new Error('README.md is missing the generated test-table markers');
  }
  const next = `${renderTestTable(rootDir)}`;
  // Exactly one blank line after the table: the rendered block ends with
  // END + newline, so collapse any run of newlines left in the tail.
  const tail = readme.slice(end + END.length).replace(/^\n*/, '\n');
  const updated = readme.slice(0, start) + next + tail;
  writeFileSync(readmePath, updated);
  return updated;
}

const isMain = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  if (write) {
    writeTestTable(root);
    console.log('Wrote README.md test table');
  } else {
    console.log(renderTestTable(root));
  }
}
