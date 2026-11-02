// Test impact analysis (Fase 5): map changed files to the suites that
// actually cover them, so a one-domain change does not pay for the full
// fleet. Anything unrecognized escalates to MODE=full — a false full run
// wastes minutes, a false selection silently drops coverage.
//
// Usage:
//   node scripts/select_tests.mjs [base-ref] [--files <paths...>]
//   SELECT_BASE env is used when no base-ref is given.
//   --files bypasses git (for testing the mapping).
// Output (shell-evaluable):
//   SELECT_MODE=selected|full
//   SELECT_REASON=...
//   SELECT_DB_SUITES="..."   (repo-relative, space-separated)
//   SELECT_CASE_FILES="..."
//   SELECT_NODE_SUITE=none|endpoints|fast|gateway|full
//   SELECT_NODE_FILES="..."   (repo-relative, space-separated)
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';

const args = process.argv.slice(2);
const flagIdx = args.indexOf('--files');
// --files bypasses git (for testing the mapping); when present, only the
// listed paths are considered, even if the list is empty.
const useExplicit = flagIdx >= 0;
const explicitFiles = useExplicit ? args.slice(flagIdx + 1) : [];
const baseArg = args.slice(0, useExplicit ? flagIdx : args.length).find((a) => !a.startsWith('--'));

function git(args) {
  try {
    return execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    return null;
  }
}

function resolveBase(explicit) {
  if (explicit) {
    if (git(['rev-parse', '--verify', '--quiet', explicit]) === null) {
      console.error(`FAIL: unknown base ref: ${explicit}`);
      process.exit(2);
    }
    return explicit;
  }
  if (process.env.SELECT_BASE) return resolveBase(process.env.SELECT_BASE);
  if (git(['rev-parse', '--verify', '--quiet', 'origin/main']) !== null) return 'origin/main';
  if (git(['rev-parse', '--verify', '--quiet', 'HEAD~1']) !== null) return 'HEAD~1';
  return null;
}

function changedFiles(base) {
  if (base === null) return null; // cannot tell -> full
  // Three-dot: changes since the merge-base (PR semantics). Plus untracked
  // files, which git diff never reports but which can add suites.
  const out = git(['diff', '--name-only', `${base}...HEAD`]);
  if (out === null) return null;
  const untracked = git(['ls-files', '--others', '--exclude-standard']) || '';
  return [
    ...new Set(
      (out + '\n' + untracked)
        .split('\n')
        .map((s) => s.trim())
        .filter(Boolean),
    ),
  ].sort();
}

const KNOWN_GATE_DATA = new Set([
  'tests/baseline_counts.txt',
  'tests/warning_baseline.txt',
  'tests/known_shadowed_routes.txt',
  'tests/coverage_baseline.txt',
  'tests/probes/expectations.txt',
]);
const KNOWN_DOCS = new Set([
  'README.md',
  'CONTRIBUTING.md',
  'SECURITY.md',
  'CHANGELOG.md',
  'PLANNING_SKELETON_CONVERSION.md',
  'LICENSE',
]);

const plan = {
  mode: 'selected',
  reason: '',
  db: new Set(),
  cases: new Set(),
  nodeSuite: 'none', // none|endpoints|fast|gateway|full
  nodeFiles: new Set(),
};

const NODE_RANK = { none: 0, endpoints: 1, fast: 2, gateway: 3, full: 4 };
function needNode(level) {
  if (NODE_RANK[level] > NODE_RANK[plan.nodeSuite]) plan.nodeSuite = level;
}

function full(reason) {
  plan.mode = 'full';
  plan.reason = reason;
}

function domainOf(coreFile) {
  // cobol/src/<domain>_core.cob -> <domain>; null when not a domain module.
  const m = coreFile.match(/^cobol\/src\/([a-z0-9_]+)_core\.cob$/);
  return m ? m[1] : null;
}

function selectFile(f) {
  if (plan.mode === 'full') return;
  // Build noise, never code.
  if (/^(coverage\/|backups\/|input\.txt|output\.txt|sql_debug\.log|\.DS_Store|Thumbs\.db)/.test(f)) return;
  if (f === 'tests/.dbenv') return;
  // Docs and generated data: the static gates (always run) validate them.
  if (f.startsWith('docs/') || KNOWN_DOCS.has(f) || f === 'manifest/modules.json') return;
  if (KNOWN_GATE_DATA.has(f)) return;
  // COBOL domain module -> its DB suite + table cases.
  let m = f.match(/^cobol\/src\/([A-Za-z0-9_]+\.cob)$/);
  if (m) {
    const domain = domainOf(f);
    const suite = domain ? `tests/db/${domain}_db_tests.sh` : null;
    if (domain && suite && existsSync(suite)) {
      plan.db.add(suite);
      const cases = `tests/cobol/cases/${domain}.cases`;
      if (existsSync(cases)) plan.cases.add(cases);
      return;
    }
    return full(`COBOL source without an exact DB suite mapping: ${f}`);
  }
  // COBOL includes/bridges and build inputs affect every module.
  if (/^cobol\/(copy|c_lib)\//.test(f) || /^cobol\/src\/.*\.(c|h)$/.test(f)) {
    return full(`shared COBOL input changed: ${f}`);
  }
  if (f === 'build.sh' || f === 'cobol/Makefile') return full(`build changed: ${f}`);
  // Database surface: everything reads it.
  if (f.startsWith('database/')) return full(`database changed: ${f}`);
  // Test harness and gates: they shape every run.
  if (
    f.startsWith('tests/lib/') ||
    f.startsWith('tests/probes/') ||
    f.startsWith('tests/gateway/') ||
    f.startsWith('tests/integration/') ||
    f.startsWith('tests/fuzz/') ||
    f.startsWith('tests/perf/') ||
    f === 'tests/run_all.sh' ||
    f === 'tests/cobol/table_runner.sh' ||
    f === 'tests/cobol/skeleton_smoke.sh' ||
    f.startsWith('scripts/')
  ) {
    return full(`test harness changed: ${f}`);
  }
  // A changed DB suite re-runs itself plus its domain cases.
  m = f.match(/^tests\/db\/([a-z0-9_]+)_db_tests\.sh$/);
  if (m) {
    plan.db.add(f);
    const cases = `tests/cobol/cases/${m[1]}.cases`;
    if (existsSync(cases)) plan.cases.add(cases);
    return;
  }
  // A changed case file re-runs itself plus its domain suite.
  m = f.match(/^tests\/cobol\/cases\/([a-z0-9_]+)\.cases$/);
  if (m) {
    plan.cases.add(f);
    const suite = `tests/db/${m[1]}_db_tests.sh`;
    if (existsSync(suite)) plan.db.add(suite);
    return;
  }
  // Gateway route tables: the endpoint smoke hits every route once.
  if (/^middleware\/src\/routes\/.+\.js$/.test(f)) {
    needNode('endpoints');
    return;
  }
  // One-off test data and test files run by themselves.
  if (f === 'middleware/test/fixtures/field_order_contract.json') {
    plan.nodeFiles.add('middleware/test/field_order.test.js');
    return;
  }
  if (f === 'middleware/test/support.js') return needNode('full');
  m = f.match(/^middleware\/test\/(.+\.test\.js)$/);
  if (m) {
    plan.nodeFiles.add(`middleware/test/${m[1]}`);
    return;
  }
  // Shared gateway code: cannot map precisely.
  if (f.startsWith('middleware/')) return needNode('full');
  // CI, release process, and anything else: prove nothing is missed.
  if (f.startsWith('.github/') || f.startsWith('scripts/ci/')) {
    return full(`CI config changed: ${f}`);
  }
  return full(`no mapping for: ${f}`);
}

let files;
if (useExplicit) {
  files = [...new Set(explicitFiles.map((s) => s.trim()).filter(Boolean))].sort();
} else {
  const base = resolveBase(baseArg);
  if (base === null) {
    console.log('SELECT_MODE="full"');
    console.log('SELECT_REASON="no git base available (not a repo or no history)"');
    console.log('SELECT_DB_SUITES=""');
    console.log('SELECT_CASE_FILES=""');
    console.log('SELECT_NODE_SUITE="full"');
    console.log('SELECT_NODE_FILES=""');
    process.exit(0);
  }
  files = changedFiles(base);
  if (files === null) {
    console.log('SELECT_MODE="full"');
    console.log('SELECT_REASON="git diff failed"');
    console.log('SELECT_DB_SUITES=""');
    console.log('SELECT_CASE_FILES=""');
    console.log('SELECT_NODE_SUITE="full"');
    console.log('SELECT_NODE_FILES=""');
    process.exit(0);
  }
}

for (const f of files) selectFile(f);

if (plan.mode === 'selected' && files.length === 0) {
  plan.reason = 'no changes detected';
} else if (plan.mode === 'selected') {
  const parts = [];
  if (plan.db.size) parts.push(`${plan.db.size} db suite(s)`);
  if (plan.cases.size) parts.push(`${plan.cases.size} case file(s)`);
  if (plan.nodeSuite !== 'none' || plan.nodeFiles.size) parts.push(`node:${plan.nodeSuite}`);
  plan.reason = parts.length ? parts.join(', ') : 'static gates + build + smoke only';
}

console.log(`SELECT_MODE="${plan.mode}"`);
console.log(`SELECT_REASON="${plan.reason || 'full run required'}"`);
console.log(`SELECT_DB_SUITES="${[...plan.db].sort().join(' ')}"`);
console.log(`SELECT_CASE_FILES="${[...plan.cases].sort().join(' ')}"`);
console.log(`SELECT_NODE_SUITE="${plan.nodeSuite}"`);
console.log(`SELECT_NODE_FILES="${[...plan.nodeFiles].sort().join(' ')}"`);
