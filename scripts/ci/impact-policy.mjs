// Impact policy for CI targeting (PR-01).
//
// Pure mapping from a repo-relative changed path to a plan fragment.
// This module performs NO I/O: it never touches the filesystem, git, or the
// network. Existence checks (does the mapped suite/case file really exist?)
// and coverage-list lookups (is the suite in coverage-suites.txt?) live in
// scripts/ci/impact-plan.mjs, which passes the answers in as arguments.
//
// Dispatch is table-driven (RULES below, first match wins) so the function
// stays under the JS complexity ratchet. The order is load-bearing:
//   - tests/coverage_* before tests/*baseline* (coverage, not static)
//   - scripts/ci/coverage* before scripts/ci/** meta
//   - tests/db/** and tests/cobol/cases/** before the tests/** fallback
//   - middleware/src/routes/** before middleware/src/**
//   - middleware/test/*.test.js and the field_order fixture before
//     middleware/test/** support
// Unknown paths fall back to full runtime (never skip).
export const MODES = ['docs', 'static', 'coverage', 'code', 'full'];

const MODE_RANK = { docs: 0, static: 1, coverage: 2, code: 3, full: 4 };
const TEST_RANK = { none: 0, selected: 1, full: 2 };
const NODE_RANK = { none: 0, unit: 1, endpoints: 2, fast: 3, gateway: 4, full: 5 };
const DB_RANK = { none: 0, selected: 1, full: 2 };
const INT_RANK = { none: 0, selected: 1, full: 2 };

const DOCS_FILES = new Set(['README.md', 'CONTRIBUTING.md', 'SECURITY.md', 'CHANGELOG.md', 'LICENSE']);
const DOCS_PREFIXES = ['docs/', '.github/ISSUE_TEMPLATE/'];
const DOCS_EXACT = new Set(['.github/pull_request_template.md', '.github/CODEOWNERS']);

const STATIC_PREFIXES = [
  'manifest/',
  'contracts/',
  'tests/fixtures/',
  'tests/contracts/',
  'tests/scripts/test_',
  'tests/perf/',
  'tests/probes/',
  'tests/.dbenv',
  'monitoring/',
  'artifacts/',
  'backups/',
  'coverage/',
  'data/',
];
const STATIC_EXACT = new Set([
  'tests/README.md',
  'tests/scripts/run.sh',
  'Makefile',
  'package.json',
  'package-lock.json',
  'eslint.config.mjs',
  'docker-compose.test.yml',
  'ci.sh',
  'ci-fast.sh',
  'input.txt',
  'output.txt',
  'sql_debug.log',
  '.DS_Store',
  'Thumbs.db',
]);
const STATIC_TESTS_RES = [/^tests\/[^/]*baseline[^/]*\.txt$/, /^tests\/[^/]+\.(txt|json)$/];

function base(name) {
  return {
    mode: name,
    lint: 'full',
    build: false,
    test: 'none',
    table_cases: [],
    node_suite: 'none',
    node_files: [],
    integration: 'none',
    integration_flows: [],
    db: 'none',
    db_suites: [],
    gateway_coverage: false,
    cobol_coverage: false,
    schema_drift: false,
    docker: false,
  };
}

function withPlan(mode, fields) {
  return { ...base(mode), ...fields };
}

function startsWithAny(f, prefixes) {
  return prefixes.some((p) => f.startsWith(p));
}

function matchesAny(f, res) {
  return res.some((re) => re.test(f));
}

function isDocs(f) {
  return DOCS_FILES.has(f) || startsWithAny(f, DOCS_PREFIXES) || DOCS_EXACT.has(f);
}

function isCoverageData(f) {
  return f.startsWith('tests/coverage_');
}

function isImageDefinition(f) {
  return f === 'Dockerfile' || f === '.dockerignore';
}

function isDotConfig(f) {
  return f.startsWith('.') && !f.startsWith('.github/');
}

function isStaticTestsPattern(f) {
  return matchesAny(f, STATIC_TESTS_RES) && !f.startsWith('tests/coverage_');
}

function isStaticGenerated(f) {
  return startsWithAny(f, STATIC_PREFIXES) || STATIC_EXACT.has(f) || isDotConfig(f) || isStaticTestsPattern(f);
}

function isCoverageTooling(f) {
  return f.startsWith('scripts/ci/coverage') || f.startsWith('scripts/coverage/');
}

function isStaticTooling(f) {
  return (
    f.startsWith('scripts/check_') ||
    f === 'scripts/generate_schema_snapshot.sh' ||
    f.startsWith('scripts/test/') ||
    f.startsWith('scripts/ci/classify_') ||
    f.startsWith('scripts/ci/impact-') ||
    f.startsWith('scripts/ci/check_') ||
    f.startsWith('scripts/ci/shard_') ||
    f.startsWith('scripts/ci/aggregate_') ||
    f === 'scripts/ci/summary.mjs' ||
    f === 'scripts/ci/compare_runs.mjs' ||
    f === 'scripts/ci/quarantine_flag.mjs' ||
    f.startsWith('scripts/ci/ci_')
  );
}

function isMigrationSuite(f) {
  return f.startsWith('tests/db/migration_');
}

function suiteDomain(suiteFile) {
  const m = suiteFile.match(/^tests\/db\/([a-z0-9_]+)_db_tests\.sh$/);
  return m ? m[1] : null;
}

function caseDomain(caseFile) {
  const m = caseFile.match(/^tests\/cobol\/cases\/([a-z0-9_]+)\.cases$/);
  return m ? m[1] : null;
}

function domainOf(coreFile) {
  const m = coreFile.match(/^cobol\/src\/([a-z0-9_]+)_core\.cob$/);
  return m ? m[1] : null;
}

function isNonCoreCobol(f) {
  return /^cobol\/src\/[^/]+\.cob$/.test(f);
}

function isSharedCobol(f) {
  return f.startsWith('cobol/copy/') || f.startsWith('cobol/c_lib/') || /^cobol\/src\/[^/]+\.[ch]$/.test(f);
}

function isBuildInput(f) {
  return f === 'build.sh' || f === 'cobol/Makefile' || f === 'scripts/ci/install_gnucobol.sh';
}

function isDatabase(f) {
  return f.startsWith('database/');
}

function isGatewayRoute(f) {
  return f.startsWith('middleware/src/routes/');
}

function isGatewaySource(f) {
  return f.startsWith('middleware/src/') || f.startsWith('middleware/spec/');
}

function isGatewayDeps(f) {
  return f === 'middleware/package.json' || f === 'middleware/package-lock.json';
}

function nodeTestFile(f) {
  const m = f.match(/^middleware\/test\/(.+\.test\.js)$/);
  return m ? m[1] : null;
}

function isFieldOrderFixture(f) {
  return f === 'middleware/test/fixtures/field_order_contract.json';
}

function isGatewayTestSupport(f) {
  return f.startsWith('middleware/test/');
}

function isGatewayTree(f) {
  return f.startsWith('middleware/');
}

function isGatewaySuite(f) {
  return f.startsWith('tests/gateway/');
}

function integrationFlow(f) {
  const m = f.match(/^tests\/integration\/([a-z0-9_]+)\.sh$/);
  return m ? m[1] : null;
}

function isHarness(f) {
  return (
    f.startsWith('tests/lib/') ||
    f.startsWith('tests/fuzz/') ||
    f.startsWith('tests/cobol/') ||
    f === 'tests/run_all.sh' ||
    f === 'tests/check_cobol_c_errors.sh' ||
    f === 'tests/db/schema_tests.sh' ||
    /^tests\/[^/]+\.sh$/.test(f)
  );
}

function isMeta(f) {
  return (
    (f.startsWith('scripts/ci/') && !f.startsWith('scripts/ci/coverage')) ||
    f.startsWith('.github/workflows/') ||
    f.startsWith('.github/actions/') ||
    f === '.github/dependabot.yml'
  );
}

function isRepoScript(f) {
  return f.startsWith('scripts/');
}

function hit(result) {
  return result !== null && result !== undefined && result !== false && result !== '';
}

function makeDocs(f) {
  return { mode: 'docs', plan: { ...base('docs'), lint: 'docs' }, reason: `docs: ${f}`, unmapped: false };
}

function makeCoverage(f, label) {
  return {
    mode: 'coverage',
    plan: withPlan('coverage', { cobol_coverage: true }),
    reason: `${label}: ${f}`,
    unmapped: false,
  };
}

function makeStatic(f, label) {
  return { mode: 'static', plan: base('static'), reason: `${label}: ${f}`, unmapped: false };
}

function makeImage(f) {
  return {
    mode: 'static',
    plan: withPlan('static', { build: true, docker: true }),
    reason: `image definition: ${f}`,
    unmapped: false,
  };
}

function makeStaticTooling(f) {
  const plan = base('static');
  if (f === 'scripts/check_schema_drift.sh' || f === 'scripts/generate_schema_snapshot.sh') {
    plan.schema_drift = true;
  }
  return { mode: 'static', plan, reason: `static tooling: ${f}`, unmapped: false };
}

function makeMigration(f) {
  return {
    mode: 'code',
    plan: withPlan('code', { build: true, test: 'selected', db: 'selected', db_suites: [f], schema_drift: true }),
    reason: `migration suite: ${f}`,
    unmapped: false,
  };
}

function makeDbSuite(f, domain) {
  return {
    mode: 'code',
    plan: withPlan('code', {
      build: true,
      test: 'selected',
      table_cases: [`tests/cobol/cases/${domain}.cases`],
      db: 'selected',
      db_suites: [f],
      gateway_coverage: true,
      cobol_coverage: { ifSuite: `${domain}_db_tests` },
    }),
    reason: `db suite: ${f}`,
    unmapped: false,
  };
}

function makeCaseFile(f, domain) {
  return {
    mode: 'code',
    plan: withPlan('code', {
      build: true,
      test: 'selected',
      table_cases: [f],
      db: 'selected',
      db_suites: [`tests/db/${domain}_db_tests.sh`],
      gateway_coverage: true,
      cobol_coverage: { ifCase: domain },
    }),
    reason: `table cases: ${f}`,
    unmapped: false,
  };
}

function makeCobolDomain(f, domain) {
  return {
    mode: 'code',
    plan: withPlan('code', {
      build: true,
      test: 'selected',
      table_cases: [`tests/cobol/cases/${domain}.cases`],
      db: 'selected',
      db_suites: [`tests/db/${domain}_db_tests.sh`],
      integration: 'full',
      gateway_coverage: true,
      cobol_coverage: { ifCurated: `${domain}_core` },
    }),
    reason: `cobol domain: ${f}`,
    unmapped: false,
  };
}

function makeFull(f, label, fields = {}) {
  return {
    mode: 'full',
    plan: withPlan('full', {
      build: true,
      test: 'full',
      integration: 'full',
      db: 'full',
      gateway_coverage: true,
      cobol_coverage: true,
      ...fields,
    }),
    reason: `${label}: ${f}`,
    unmapped: false,
  };
}

function makeDatabase(f) {
  return makeFull(f, 'database', { schema_drift: true });
}

function makeRoute(f) {
  return {
    mode: 'code',
    plan: withPlan('code', {
      build: true,
      test: 'selected',
      node_suite: 'endpoints',
      gateway_coverage: true,
      cobol_coverage: true,
    }),
    reason: `gateway route: ${f}`,
    unmapped: false,
  };
}

function makeGatewaySource(f) {
  return {
    mode: 'code',
    plan: withPlan('code', {
      build: true,
      test: 'selected',
      node_suite: 'fast',
      gateway_coverage: true,
      cobol_coverage: true,
    }),
    reason: `gateway source: ${f}`,
    unmapped: false,
  };
}

function makeGatewayDeps(f) {
  return {
    mode: 'code',
    plan: withPlan('code', {
      build: true,
      test: 'selected',
      node_suite: 'full',
      gateway_coverage: true,
      cobol_coverage: true,
      docker: true,
    }),
    reason: `gateway deps: ${f}`,
    unmapped: false,
  };
}

function makeNodeFile(f) {
  return {
    mode: 'code',
    plan: withPlan('code', { build: true, test: 'selected', node_files: [f], gateway_coverage: true }),
    reason: `node test file: ${f}`,
    unmapped: false,
  };
}

function makeFixture(f) {
  return {
    mode: 'code',
    plan: withPlan('code', {
      build: true,
      test: 'selected',
      node_files: ['middleware/test/field_order.test.js'],
      gateway_coverage: true,
    }),
    reason: `gateway fixture: ${f}`,
    unmapped: false,
  };
}

function makeGatewaySupport(f) {
  return {
    mode: 'code',
    plan: withPlan('code', {
      build: true,
      test: 'selected',
      node_suite: 'full',
      gateway_coverage: true,
      cobol_coverage: true,
    }),
    reason: `gateway support: ${f}`,
    unmapped: false,
  };
}

function makeGatewayTree(f) {
  return { ...makeGatewaySupport(f), reason: `gateway tree: ${f}` };
}

function makeGatewaySuite(f) {
  return {
    mode: 'code',
    plan: withPlan('code', { build: true, test: 'selected', node_suite: 'gateway', gateway_coverage: true }),
    reason: `gateway suite: ${f}`,
    unmapped: false,
  };
}

function makeIntegration(f, flow) {
  return {
    mode: 'code',
    plan: withPlan('code', {
      build: true,
      test: 'selected',
      integration: 'selected',
      integration_flows: [flow],
      gateway_coverage: true,
    }),
    reason: `integration flow: ${f}`,
    unmapped: false,
  };
}

function makeUnknown(f) {
  return {
    mode: 'full',
    plan: withPlan('full', {
      build: true,
      test: 'full',
      node_suite: 'full',
      integration: 'full',
      db: 'full',
      gateway_coverage: true,
      cobol_coverage: true,
      schema_drift: true,
      docker: true,
    }),
    reason: `no mapping for: ${f}`,
    unmapped: true,
  };
}

const RULES = [
  { test: isDocs, make: makeDocs },
  { test: isCoverageData, make: (f) => makeCoverage(f, 'coverage data') },
  { test: isImageDefinition, make: makeImage },
  { test: isStaticGenerated, make: (f) => makeStatic(f, 'static') },
  { test: isCoverageTooling, make: (f) => makeCoverage(f, 'coverage tooling') },
  { test: isStaticTooling, make: makeStaticTooling },
  { test: isMigrationSuite, make: makeMigration },
  { test: suiteDomain, make: makeDbSuite },
  { test: caseDomain, make: makeCaseFile },
  { test: domainOf, make: makeCobolDomain },
  { test: isNonCoreCobol, make: (f) => makeFull(f, 'cobol source') },
  { test: isSharedCobol, make: (f) => makeFull(f, 'shared cobol input') },
  {
    test: isBuildInput,
    make: (f) => makeFull(f, 'build input', { docker: true }),
  },
  { test: isDatabase, make: makeDatabase },
  { test: isGatewayRoute, make: makeRoute },
  { test: isGatewaySource, make: makeGatewaySource },
  { test: isGatewayDeps, make: makeGatewayDeps },
  { test: nodeTestFile, make: makeNodeFile },
  { test: isFieldOrderFixture, make: makeFixture },
  { test: isGatewayTestSupport, make: makeGatewaySupport },
  { test: isGatewayTree, make: makeGatewayTree },
  { test: isGatewaySuite, make: makeGatewaySuite },
  { test: integrationFlow, make: makeIntegration },
  { test: isHarness, make: (f) => makeFull(f, 'test harness') },
  { test: isMeta, make: (f) => makeStatic(f, 'ci meta') },
  { test: isRepoScript, make: (f) => makeStatic(f, 'repo script') },
];

/**
 * Classify one repo-relative path.
 * Returns { mode, plan, reason, unmapped } where plan holds the fragment
 * fields (lists are candidates; impact-plan.mjs validates existence).
 * cobol_coverage may be boolean or a conditional marker resolved by
 * planForFiles with coverage sets:
 *   { ifSuite: '<name>_db_tests' }   true when the suite is measured
 *   { ifCurated: '<module>' }         true when the module is curated
 *   { ifCase: '<domain>' }            true when the domain module is curated
 */
export function classifyFile(file) {
  const f = String(file);
  for (const rule of RULES) {
    const match = rule.test(f);
    if (hit(match)) return rule.make(f, match);
  }
  return makeUnknown(f);
}

function resolveCobol(value, suites, modules) {
  if (value === true || value === false) return value;
  if (value && typeof value === 'object') {
    if (value.ifSuite) {
      if (!suites) return true;
      return suites.has(value.ifSuite);
    }
    if (value.ifCurated) {
      if (!modules) return true;
      return modules.has(value.ifCurated);
    }
    if (value.ifCase) {
      if (!modules) return true;
      return modules.has(`${value.ifCase}_core`);
    }
  }
  return true;
}

function union(a, b) {
  return [...new Set([...a, ...b])].sort();
}

function emptyPlan() {
  return {
    lint: 'docs',
    build: false,
    test: 'none',
    table_cases: [],
    node_suite: 'none',
    node_files: [],
    integration: 'none',
    integration_flows: [],
    db: 'none',
    db_suites: [],
    gateway_coverage: false,
    cobol_coverage: false,
    schema_drift: false,
    docker: false,
  };
}

function mergeOne(merged, c, ctx) {
  if (c.plan.lint === 'full') merged.lint = 'full';
  merged.build = merged.build || c.plan.build;
  if (TEST_RANK[c.plan.test] > TEST_RANK[merged.test]) merged.test = c.plan.test;
  merged.table_cases = union(merged.table_cases, c.plan.table_cases);
  if (NODE_RANK[c.plan.node_suite] > NODE_RANK[merged.node_suite]) merged.node_suite = c.plan.node_suite;
  merged.node_files = union(merged.node_files, c.plan.node_files);
  if (INT_RANK[c.plan.integration] > INT_RANK[merged.integration]) merged.integration = c.plan.integration;
  merged.integration_flows = union(merged.integration_flows, c.plan.integration_flows);
  if (DB_RANK[c.plan.db] > DB_RANK[merged.db]) merged.db = c.plan.db;
  merged.db_suites = union(merged.db_suites, c.plan.db_suites);
  merged.gateway_coverage = merged.gateway_coverage || c.plan.gateway_coverage;
  merged.cobol_coverage = merged.cobol_coverage || resolveCobol(c.plan.cobol_coverage, ctx.suites, ctx.modules);
  merged.schema_drift = merged.schema_drift || c.plan.schema_drift;
  merged.docker = merged.docker || c.plan.docker;
}

/**
 * Merge classifications for a file list.
 * opts: { suites: Set<string>|null, modules: Set<string>|null }
 * (coverage names without extensions, e.g. 'loan_db_tests', 'loan_core').
 * Null sets resolve conditionals conservatively to true.
 */
export function planForFiles(files, opts = {}) {
  const list = [...new Set((files || []).map((s) => String(s).trim()).filter(Boolean))].sort();
  const ctx = { suites: opts.suites ?? null, modules: opts.modules ?? null };
  const merged = emptyPlan();
  if (!list.length) {
    return { mode: 'docs', plan: merged, reason: 'no changes detected', unmapped: [] };
  }
  let mode = 'docs';
  const unmapped = [];
  const reasons = [];
  for (const f of list) {
    const c = classifyFile(f);
    reasons.push(c.reason);
    if (MODE_RANK[c.mode] > MODE_RANK[mode]) mode = c.mode;
    mergeOne(merged, c, ctx);
    if (c.unmapped) unmapped.push(f);
  }
  if (mode === 'docs' && merged.lint === 'full') mode = 'static';
  const reason =
    unmapped.length > 0
      ? `fallback: no mapping for ${unmapped.length} path(s)`
      : reasons.length === 1
        ? reasons[0]
        : `${mode}: ${list.length} file(s)`;
  return { mode, plan: merged, reason, unmapped };
}
