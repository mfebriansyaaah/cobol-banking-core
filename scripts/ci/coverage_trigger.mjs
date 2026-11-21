// Coverage trigger classifier (CI-004, PR-05 precision).
//
// Decides whether a change set requires the curated COBOL coverage
// measurement (`scripts/ci/coverage.sh --cobol-only --changed`) and whether
// it requires the gateway coverage gate. Two independent dimensions:
//
//   gateway  gateway suite behavior may change (middleware, gateway suites,
//            shared suite helpers).
//   cobol    curated COBOL line coverage may change (COBOL sources, database
//            surface, measurement tooling, curated suites/cases).
//
// Known-safe paths (docs, contracts, manifest, baselines, CI config) trigger
// neither. Anything else is `unknown` and triggers neither here: the impact
// planner (`scripts/ci/impact-plan.mjs`) fails safe to full separately, so
// an unmapped path still runs the whole fleet.
//
// Suite/case conditionals resolve against scripts/ci/coverage-suites.txt and
// scripts/ci/coverage-modules.txt (the same files coverage.sh measures).
// A null set resolves conservatively to true (cannot tell).
//
// Usage:
//   node scripts/ci/coverage_trigger.mjs [--stdin] [files...]
// Exit 0 when the COBOL measurement is required, 1 when it can be skipped.
// Prints the first triggering `trigger:<dimension>:<file>` on stdout.
//
// Pure functions (classifyCoverage, shouldMeasureCobol, shouldMeasureGateway)
// are imported by scripts/test/coverage_trigger.test.mjs.
const GATEWAY_RULES = [
  /^middleware\/src\//,
  /^middleware\/test\//,
  /^middleware\/spec\//,
  /^tests\/gateway\//,
  /^tests\/lib\//,
];

const COBOL_RULES = [
  /^cobol\/src\//,
  /^cobol\/copy\//,
  /^cobol\/c_lib\//,
  /^build\.sh$/,
  /^cobol\/Makefile$/,
  /^database\//,
  // Gateway routes exercise COBOL actions through the instrumented binary;
  // a route change can drop measured COBOL lines, so re-measure.
  /^middleware\/src\/routes\//,
  /^scripts\/ci\/coverage\.sh$/,
  /^scripts\/coverage\//,
  /^tests\/coverage_/,
  /^tests\/cobol\/table_runner\.sh$/,
];

// Generated or volatile paths that can never affect either measurement.
const SAFE_RULES = [
  /^docs\//,
  /^(README\.md|CONTRIBUTING\.md|SECURITY\.md|CHANGELOG\.md|LICENSE)$/,
  /^manifest\//,
  /^contracts\//,
  /^tests\/README\.md$/,
  /^tests\/[^/]*baseline[^/]*\.txt$/,
  /^tests\/[^/]+\.(txt|json)$/,
  /^tests\/fixtures\//,
  /^tests\/contracts\//,
  /^tests\/scripts\//,
  /^tests\/perf\//,
  /^tests\/probes\//,
  /^tests\/\.dbenv/,
  /^monitoring\//,
  /^Makefile$/,
  /^package\.json$/,
  /^package-lock\.json$/,
  /^eslint\.config\.mjs$/,
  /^docker-compose\.test\.yml$/,
  /^ci\.sh$/,
  /^ci-fast\.sh$/,
  /^data\//,
  /^(input\.txt|output\.txt|sql_debug\.log|\.DS_Store|Thumbs\.db)$/,
  /^(coverage\/|artifacts\/|backups\/|test-results\/|reports\/|tmp\/)/,
  /^\./,
  /^Dockerfile$/,
  /^\.dockerignore$/,
  /^scripts\/check_/,
  /^scripts\/generate_schema_snapshot\.sh$/,
  /^scripts\/test\//,
  /^scripts\/ci\/classify_/,
  /^scripts\/ci\/impact-/,
  /^scripts\/ci\/check_/,
  /^scripts\/ci\/shard_/,
  /^scripts\/ci\/aggregate_/,
  /^scripts\/ci\/summary\.mjs$/,
  /^scripts\/ci\/compare_runs\.mjs$/,
  /^scripts\/ci\/quarantine_flag\.mjs$/,
  /^scripts\/ci\/ci_/,
  /^scripts\/ci\//,
  /^\.github\//,
];

function suiteName(suiteFile) {
  const m = String(suiteFile).match(/^tests\/db\/([a-z0-9_]+_db_tests)\.sh$/);
  return m ? m[1] : null;
}

function caseDomain(caseFile) {
  const m = String(caseFile).match(/^tests\/cobol\/cases\/([a-z0-9_]+)\.cases$/);
  return m ? m[1] : null;
}

/**
 * Classify one path. Returns { gateway, cobol } booleans. Conditional
 * suite/case hits resolve against ctx ({ suites:Set|null, modules:Set|null }).
 */
export function classifyCoverage(file, ctx = {}) {
  const f = String(file);
  if (!f) return { gateway: false, cobol: false };
  const { suites = null, modules = null } = ctx;
  let gateway = GATEWAY_RULES.some((re) => re.test(f));
  let cobol = COBOL_RULES.some((re) => re.test(f));
  if (!cobol) {
    const suite = suiteName(f);
    if (suite) {
      cobol = suites === null ? true : suites.has(suite);
    } else {
      const domain = caseDomain(f);
      if (domain) cobol = modules === null ? true : modules.has(`${domain}_core`);
    }
  }
  if (!gateway && !cobol && !SAFE_RULES.some((re) => re.test(f))) {
    return { gateway: false, cobol: false };
  }
  return { gateway, cobol };
}

/** True when at least one path requires the curated COBOL measurement. */
export function shouldMeasureCobol(files, ctx = {}) {
  return (files || []).some((f) => classifyCoverage(f, ctx).cobol);
}

/** True when at least one path requires the gateway coverage gate. */
export function shouldMeasureGateway(files, ctx = {}) {
  return (files || []).some((f) => classifyCoverage(f, ctx).gateway);
}

/**
 * Legacy single-dimension view for scripts that only gate the COBOL
 * measurement (coverage.sh --changed): a trigger group string, or null
 * when the path is known-safe. Unknown paths return 'unknown' (measure).
 * Prefer classifyCoverage for new callers.
 */
export function classifyFile(file, ctx = {}) {
  const f = String(file);
  if (!f) return null;
  const { gateway, cobol } = classifyCoverage(f, ctx);
  if (cobol) return 'cobol';
  if (gateway) return 'gateway';
  if (SAFE_RULES.some((re) => re.test(f))) return null;
  return 'unknown';
}

/** Legacy predicate: true when at least one path is not known-safe. */
export function shouldMeasure(files, ctx = {}) {
  return (files || []).some((f) => classifyFile(f, ctx) !== null);
}

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const TRIGGER_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

function readTriggerList(rel) {
  try {
    const names = readFileSync(path.join(TRIGGER_ROOT, rel), 'utf8')
      .split('\n')
      .map((s) => s.trim())
      .filter((s) => s && !s.startsWith('#'));
    return new Set(names);
  } catch {
    return null;
  }
}

function readStdin() {
  return new Promise((resolve, reject) => {
    let s = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => {
      s += c;
    });
    process.stdin.on('end', () => resolve(s));
    process.stdin.on('error', reject);
  });
}

const args = process.argv.slice(2);
if (import.meta.url === `file://${process.argv[1]}`) {
  const run = async () => {
    let files = args.filter((a) => a !== '--stdin' && a !== '--help' && a !== '-h');
    if (args.includes('--help') || args.includes('-h')) {
      console.log('usage: coverage_trigger.mjs [--stdin] [files...]');
      process.exit(0);
    }
    if (args.includes('--stdin')) {
      const raw = await readStdin();
      files = [
        ...files,
        ...raw
          .split('\n')
          .map((l) => l.trim())
          .filter(Boolean),
      ];
    }
    const ctx = {
      suites: readTriggerList('scripts/ci/coverage-suites.txt'),
      modules: readTriggerList('scripts/ci/coverage-modules.txt'),
    };
    const hit = files.find((f) => classifyCoverage(f, ctx).cobol);
    if (hit === undefined) {
      process.exit(1);
    }
    console.log(`trigger:${classifyFile(hit, ctx)}:${hit}`);
    process.exit(0);
  };
  run();
}
