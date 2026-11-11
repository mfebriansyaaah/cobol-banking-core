// PR size reporter (maint-00): total vs generated vs reviewable diff.
//
// Line count is NOT a gate. This script only reports numbers for the PR
// body (Size tier / Total diff / Semantic diff). Reviewers judge the
// reviewable diff, not the total.
//
// Generated paths are derived artifacts: a large total driven by them is
// expected and must be reviewed with the generator diff, not line by line.
// Formatting-only changes are NOT detected here; reviewers use
// `git diff -w` for that (see master plan §3.2).
//
// Usage:
//   node scripts/pr_size.mjs [--base REF] [--head REF] [--json] [root]
//   --base REF   compare base (default: origin/main)
//   --head REF   compare head (default: HEAD)
//   --json       machine-readable output
// Exit: 0 always (informational; never fail the build).
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

// Paths that are derived artifacts, not hand-written logic. A bulk diff in
// these files is reviewed via the generator, not line by line.
export const GENERATED_PREFIXES = [
  'manifest/',
  'contracts/',
  'docs/STATUS.md',
  'docs/MODULE_INDEX.md',
  'docs/openapi.yaml',
  'tests/contracts/',
  'database/schema_full.sql',
  'database/schema_v2.sql',
  'artifacts/',
  'coverage/',
];

export function classifyFile(file) {
  const f = String(file || '');
  for (const prefix of GENERATED_PREFIXES) {
    if (f === prefix || f.startsWith(prefix)) return 'generated';
  }
  return 'reviewable';
}

export function summarize(rows) {
  const out = {
    files: 0,
    added: 0,
    deleted: 0,
    total: 0,
    generatedFiles: 0,
    generatedAdded: 0,
    generatedDeleted: 0,
    generatedTotal: 0,
    reviewableFiles: 0,
    reviewableAdded: 0,
    reviewableDeleted: 0,
    reviewableTotal: 0,
  };
  for (const row of rows) {
    const added = Number(row.added) || 0;
    const deleted = Number(row.deleted) || 0;
    out.files += 1;
    out.added += added;
    out.deleted += deleted;
    out.total += added + deleted;
    if (classifyFile(row.file) === 'generated') {
      out.generatedFiles += 1;
      out.generatedAdded += added;
      out.generatedDeleted += deleted;
      out.generatedTotal += added + deleted;
    } else {
      out.reviewableFiles += 1;
      out.reviewableAdded += added;
      out.reviewableDeleted += deleted;
      out.reviewableTotal += added + deleted;
    }
  }
  return out;
}

export function parseNumstat(text) {
  const rows = [];
  for (const line of String(text || '').split('\n')) {
    const m = line.match(/^(\d+|-)\s+(\d+|-)\s+(.+)$/);
    if (!m) continue;
    rows.push({
      added: m[1] === '-' ? 0 : Number(m[1]),
      deleted: m[2] === '-' ? 0 : Number(m[2]),
      file: m[3].trim(),
    });
  }
  return rows;
}

function parseArgs(argv) {
  let base = 'origin/main';
  let head = 'HEAD';
  let json = false;
  let root = '.';
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--base') {
      base = argv[i + 1] ?? base;
      i += 1;
    } else if (a.startsWith('--base=')) {
      base = a.slice('--base='.length) || base;
    } else if (a === '--head') {
      head = argv[i + 1] ?? head;
      i += 1;
    } else if (a.startsWith('--head=')) {
      head = a.slice('--head='.length) || head;
    } else if (a === '--json') {
      json = true;
    } else if (a === '--help' || a === '-h') {
      console.log('usage: pr_size.mjs [--base REF] [--head REF] [--json] [root]');
      process.exit(0);
    } else if (a.startsWith('--')) {
      console.error(`unknown argument: ${a}`);
      process.exit(2);
    } else {
      root = a;
    }
  }
  return { base, head, json, root };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const { base, head, json, root } = parseArgs(process.argv.slice(2));
  const dir = path.resolve(root);
  let numstat = '';
  try {
    numstat = execFileSync('git', ['diff', '--numstat', `${base}...${head}`], {
      cwd: dir,
      encoding: 'utf8',
      timeout: 60000,
    });
  } catch (err) {
    console.error(`FAIL: cannot diff ${base}...${head}: ${err.message}`);
    process.exit(2);
  }
  const summary = summarize(parseNumstat(numstat));
  if (json) {
    console.log(JSON.stringify({ base, head, ...summary }, null, 2));
  } else {
    console.log(`base: ${base}  head: ${head}`);
    console.log(
      `total: ${summary.total} lines (added ${summary.added}, deleted ${summary.deleted}) across ${summary.files} file(s)`,
    );
    console.log(`generated: ${summary.generatedTotal} lines across ${summary.generatedFiles} file(s)`);
    console.log(`reviewable: ${summary.reviewableTotal} lines across ${summary.reviewableFiles} file(s)`);
    console.log('note: formatting-only changes need `git diff -w` review; this report does not detect them.');
  }
}
