// Impact plan CLI (PR-01).
//
// Computes the CI impact plan for a change set and, unless PLAN_ENFORCE=true,
// the effective outputs that reproduce the legacy behavior exactly (shadow).
//
// Usage:
//   node scripts/ci/impact-plan.mjs --base <ref> [--out <file>]
//       [--github-output <file>] [--json]
//   node scripts/ci/impact-plan.mjs --files <paths...> [--out <file>]
//       [--github-output <file>] [--json]
//   node scripts/ci/impact-plan.mjs --fallback-full [--github-output <file>]
//
// Exit: 0 always, except 2 on usage errors. Any planning failure degrades to
// a full-runtime plan (fail safe, never skip).
import { execFileSync } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { planForFiles } from './impact-policy.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

const PLAN_KEYS = [
  'plan_mode',
  'plan_lint',
  'plan_build',
  'plan_test',
  'plan_table_cases',
  'plan_node_suite',
  'plan_node_files',
  'plan_integration',
  'plan_integration_flows',
  'plan_db',
  'plan_db_suites',
  'plan_gateway_coverage',
  'plan_cobol_coverage',
  'plan_schema_drift',
  'plan_docker',
  'plan_enforce',
  'plan_reason',
  'plan_unmapped',
  'eff_lint',
  'eff_build',
  'eff_test',
  'eff_table_cases',
  'eff_node_suite',
  'eff_node_files',
  'eff_integration',
  'eff_integration_flows',
  'eff_db',
  'eff_db_suites',
  'eff_gateway_coverage',
  'eff_cobol_coverage',
  'eff_schema_drift',
  'eff_docker',
  'eff_aggregate',
  'eff_aggregate_mode',
  'eff_db_snapshot',
];

function usage() {
  console.log(
    'usage: impact-plan.mjs [--base <ref>] [--files <paths...>] [--out <file>] [--github-output <file>] [--json] | --fallback-full [--github-output <file>]',
  );
}

const VALUE_FLAGS = new Set(['--base', '--out', '--github-output']);
const FLAG_ATTRS = { '--base': 'base', '--out': 'out', '--github-output': 'githubOutput' };

function splitFlag(arg) {
  const eq = arg.indexOf('=');
  if (eq < 0) return { name: arg, inline: null };
  return { name: arg.slice(0, eq), inline: arg.slice(eq + 1) };
}

function takeFiles(argv, i, out) {
  out.files = [];
  let j = i;
  while (j + 1 < argv.length && !argv[j + 1].startsWith('--')) {
    out.files.push(argv[j + 1]);
    j += 1;
  }
  return j;
}

function takeValuedFlag(argv, i, name, inline, out) {
  const attr = FLAG_ATTRS[name];
  if (inline !== null) {
    out[attr] = inline || null;
    return i;
  }
  out[attr] = argv[i + 1] ?? null;
  return i + 1;
}

function parseArgs(argv) {
  const out = { base: null, files: null, out: null, githubOutput: null, json: false, fallbackFull: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--files') {
      i = takeFiles(argv, i, out);
    } else if (a === '--json') {
      out.json = true;
    } else if (a === '--fallback-full') {
      out.fallbackFull = true;
    } else if (a === '--help' || a === '-h') {
      usage();
      process.exit(0);
    } else {
      const { name, inline } = splitFlag(a);
      if (!VALUE_FLAGS.has(name)) {
        console.error(`unknown argument: ${a}`);
        process.exit(2);
      }
      i = takeValuedFlag(argv, i, name, inline, out);
    }
  }
  return out;
}

function git(args) {
  try {
    return execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], cwd: ROOT }).trim();
  } catch {
    return null;
  }
}

function resolveBase(explicit) {
  if (explicit) {
    return git(['rev-parse', '--verify', '--quiet', explicit]) === null ? null : explicit;
  }
  for (const env of ['PR_BASE_SHA', 'PUSH_BEFORE_SHA']) {
    const v = (process.env[env] || '').trim();
    if (v && git(['rev-parse', '--verify', '--quiet', v]) !== null) return v;
  }
  if (git(['rev-parse', '--verify', '--quiet', 'origin/main']) !== null) return 'origin/main';
  if (git(['rev-parse', '--verify', '--quiet', 'HEAD~1']) !== null) return 'HEAD~1';
  return null;
}

function changedFiles(base) {
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

function readListFile(rel) {
  try {
    return new Set(
      readFileSync(path.join(ROOT, rel), 'utf8')
        .split('\n')
        .map((s) => s.trim())
        .filter((s) => s && !s.startsWith('#')),
    );
  } catch {
    return new Set();
  }
}

const bool = (v) => String(v ?? '').trim() === 'true';
const str = (v) => (v === true ? 'true' : v === false ? 'false' : String(v ?? ''));

function fullPlan(reason) {
  return {
    mode: 'full',
    plan: {
      lint: 'full',
      build: true,
      test: 'full',
      table_cases: [],
      node_suite: 'full',
      node_files: [],
      integration: 'full',
      integration_flows: [],
      db: 'full',
      db_suites: [],
      gateway_coverage: true,
      cobol_coverage: true,
      schema_drift: true,
      docker: true,
    },
    reason,
    unmapped: ['full'],
  };
}

// Filter candidate lists to files that exist, except entries that are
// themselves part of the change set (added/deleted paths stay visible).
function filterExisting(candidates, files) {
  const changed = new Set(files);
  return candidates.filter((p) => changed.has(p) || existsSync(path.join(ROOT, p)));
}

function legacyEffective(event, legacy) {
  const docsOnly = bool(legacy.docsOnly);
  if (event === 'push') return legacyPushEffective(docsOnly, legacy);
  if (event === 'workflow_dispatch') return legacyDispatchEffective(docsOnly);
  return legacyPrEffective(docsOnly, legacy);
}

function legacyPushEffective(docsOnly, legacy) {
  return {
    lint: 'full',
    build: str(!docsOnly),
    test: 'none',
    table_cases: '',
    node_suite: 'none',
    node_files: '',
    integration: 'none',
    integration_flows: '',
    db: 'none',
    db_suites: '',
    gateway_coverage: 'false',
    cobol_coverage: 'false',
    schema_drift: 'false',
    docker: str(!docsOnly),
    aggregate: 'false',
    aggregate_mode: '',
    db_snapshot: str(bool(legacy.dbOpsRelevant)),
  };
}

function legacyDispatchEffective(docsOnly) {
  return {
    lint: 'full',
    build: str(!docsOnly),
    test: 'none',
    table_cases: '',
    node_suite: 'none',
    node_files: '',
    integration: 'none',
    integration_flows: '',
    db: 'none',
    db_suites: '',
    gateway_coverage: 'true',
    cobol_coverage: 'false',
    schema_drift: 'true',
    docker: str(!docsOnly),
    aggregate: 'false',
    aggregate_mode: '',
    db_snapshot: 'true',
  };
}

function legacyPrEffective(docsOnly, legacy) {
  const test = docsOnly ? 'none' : 'full';
  return {
    lint: 'full',
    build: str(!docsOnly),
    test,
    table_cases: '',
    node_suite: 'none',
    node_files: '',
    integration: test === 'full' ? 'full' : 'none',
    integration_flows: '',
    db: docsOnly ? 'none' : String(legacy.selectMode || 'full'),
    db_suites: docsOnly ? '' : String(legacy.selectSuites || ''),
    gateway_coverage: str(!docsOnly),
    cobol_coverage: str(!docsOnly && bool(legacy.coverageRelevant)),
    schema_drift: str(!docsOnly),
    docker: str(!docsOnly && bool(legacy.dockerRelevant) && bool(legacy.dockerDefinition)),
    aggregate: str(!docsOnly),
    aggregate_mode: String(legacy.selectMode || 'full'),
    db_snapshot: str(!docsOnly),
  };
}

function enforcedEffective(plan, event, legacy) {
  const eff = {
    lint: plan.lint,
    build: str(plan.build),
    test: plan.test,
    table_cases: plan.table_cases.join(' '),
    node_suite: plan.node_suite,
    node_files: plan.node_files.join(' '),
    integration: plan.integration,
    integration_flows: plan.integration_flows.join(' '),
    db: plan.db,
    db_suites: plan.db_suites.join(' '),
    gateway_coverage: str(plan.gateway_coverage),
    cobol_coverage: str(plan.cobol_coverage),
    schema_drift: str(plan.schema_drift),
    docker: str(plan.docker),
    aggregate: '',
    aggregate_mode: '',
    db_snapshot: '',
  };
  eff.aggregate = eff.test !== 'none' && eff.gateway_coverage === 'true' ? 'true' : 'false';
  eff.aggregate_mode = eff.db === 'none' ? 'selected' : eff.db;
  eff.db_snapshot = snapshotNeeded(eff) ? 'true' : 'false';
  if (event === 'push') applyPushOverride(eff, legacy);
  else if (event === 'workflow_dispatch') applyDispatchOverride(eff);
  return eff;
}

function snapshotNeeded(eff) {
  return (
    eff.db !== 'none' ||
    eff.test !== 'none' ||
    eff.gateway_coverage === 'true' ||
    eff.cobol_coverage === 'true' ||
    eff.schema_drift === 'true'
  );
}

function applyPushOverride(eff, legacy) {
  eff.test = 'none';
  eff.db = 'none';
  eff.db_suites = '';
  eff.aggregate = 'false';
  eff.aggregate_mode = '';
  eff.gateway_coverage = 'false';
  eff.cobol_coverage = 'false';
  eff.schema_drift = 'false';
  eff.db_snapshot = str(bool(legacy.dbOpsRelevant));
  eff.lint = 'full';
}

function applyDispatchOverride(eff) {
  eff.test = 'none';
  eff.db = 'none';
  eff.db_suites = '';
  eff.aggregate = 'false';
  eff.aggregate_mode = '';
  eff.gateway_coverage = 'true';
  eff.cobol_coverage = 'false';
  eff.schema_drift = 'true';
  eff.db_snapshot = 'true';
  eff.build = 'true';
  eff.docker = 'true';
  eff.lint = 'full';
}

function computeEffective({ plan, event, enforce, legacy }) {
  if (!enforce) return legacyEffective(event, legacy);
  return enforcedEffective(plan, event, legacy);
}

function toOutputs({ result, enforce, event }) {
  const { mode, plan, reason, unmapped } = result;
  const eff = computeEffective({
    plan,
    event,
    enforce,
    legacy: {
      docsOnly: process.env.DOCS_ONLY,
      dockerRelevant: process.env.DOCKER_RELEVANT,
      dockerDefinition: process.env.DOCKER_DEFINITION,
      coverageRelevant: process.env.COVERAGE_RELEVANT,
      dbOpsRelevant: process.env.DB_OPS_RELEVANT,
      selectMode: process.env.SELECT_MODE,
      selectSuites: process.env.SELECT_DB_SUITES,
    },
  });
  const join = (v) => (Array.isArray(v) ? v.join(' ') : str(v));
  return {
    plan_mode: mode,
    plan_lint: plan.lint,
    plan_build: str(plan.build),
    plan_test: plan.test,
    plan_table_cases: join(plan.table_cases),
    plan_node_suite: plan.node_suite,
    plan_node_files: join(plan.node_files),
    plan_integration: plan.integration,
    plan_integration_flows: join(plan.integration_flows),
    plan_db: plan.db,
    plan_db_suites: join(plan.db_suites),
    plan_gateway_coverage: str(plan.gateway_coverage),
    plan_cobol_coverage: str(plan.cobol_coverage),
    plan_schema_drift: str(plan.schema_drift),
    plan_docker: str(plan.docker),
    plan_enforce: str(enforce),
    plan_reason: reason,
    plan_unmapped: unmapped.join(' '),
    eff_lint: eff.lint,
    eff_build: eff.build,
    eff_test: eff.test,
    eff_table_cases: eff.table_cases,
    eff_node_suite: eff.node_suite,
    eff_node_files: eff.node_files,
    eff_integration: eff.integration,
    eff_integration_flows: eff.integration_flows,
    eff_db: eff.db,
    eff_db_suites: eff.db_suites,
    eff_gateway_coverage: eff.gateway_coverage,
    eff_cobol_coverage: eff.cobol_coverage,
    eff_schema_drift: eff.schema_drift,
    eff_docker: eff.docker,
    eff_aggregate: eff.aggregate,
    eff_aggregate_mode: eff.aggregate_mode,
    eff_db_snapshot: eff.db_snapshot,
  };
}

function writeGithubOutput(file, outputs) {
  const lines = PLAN_KEYS.map((k) => `${k}=${outputs[k] ?? ''}`).join('\n') + '\n';
  appendFileSync(file, lines, 'utf8');
}

function emit(result, { out, githubOutput, json, enforce, event, head }) {
  const outputs = toOutputs({ result, enforce, event });
  const doc = {
    version: 1,
    base: result.base,
    head,
    files: result.files,
    mode: result.mode,
    plan: {
      lint: result.plan.lint,
      build: result.plan.build,
      test: result.plan.test,
      table_cases: result.plan.table_cases,
      node_suite: result.plan.node_suite,
      node_files: result.plan.node_files,
      integration: result.plan.integration,
      integration_flows: result.plan.integration_flows,
      db: result.plan.db,
      db_suites: result.plan.db_suites,
      gateway_coverage: result.plan.gateway_coverage,
      cobol_coverage: result.plan.cobol_coverage,
      schema_drift: result.plan.schema_drift,
      docker: result.plan.docker,
    },
    reason: result.reason,
    unmapped: result.unmapped,
    would_skip: wouldSkip(result.plan, event, bool(process.env.DB_OPS_RELEVANT)),
  };
  if (out) {
    mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
    writeFileSync(out, `${JSON.stringify(doc, null, 2)}\n`, 'utf8');
  }
  if (githubOutput) writeGithubOutput(githubOutput, outputs);
  console.log(JSON.stringify(json ? { ...doc, outputs } : doc, null, 2));
}

const SKIP_RULES = [
  { job: 'build', skip: (p) => !p.build },
  { job: 'docker-build', skip: (p) => !p.docker },
  {
    job: 'db-snapshot',
    skip: (p) => p.db === 'none' && p.test === 'none' && !p.gateway_coverage && !p.cobol_coverage && !p.schema_drift,
  },
  { job: 'schema-drift', skip: (p) => !p.schema_drift },
  { job: 'test', skip: (p) => p.test === 'none' },
  { job: 'db-shards', skip: (p) => p.db !== 'full' },
  { job: 'db-selected', skip: (p) => p.db !== 'selected' },
  { job: 'coverage', skip: (p) => !p.gateway_coverage },
  { job: 'coverage-pr', skip: (p) => !p.cobol_coverage },
  { job: 'db-aggregate', skip: (p) => !(p.test !== 'none' && p.gateway_coverage) },
  { job: 'db-ops', skip: (p, event, dbOpsRelevant) => event !== 'push' || !dbOpsRelevant },
];

export function wouldSkip(plan, event = 'pull_request', dbOpsRelevant = false) {
  const skip = [];
  for (const rule of SKIP_RULES) {
    if (rule.skip(plan, event, dbOpsRelevant)) skip.push(rule.job);
  }
  return skip.sort();
}

function collectMissing(plan, files) {
  const missing = [];
  const kept = {};
  for (const key of ['db_suites', 'table_cases', 'node_files']) {
    kept[key] = filterExisting(plan[key], files);
    if (kept[key].length !== plan[key].length) {
      for (const p of plan[key]) {
        if (!kept[key].includes(p)) missing.push(p);
      }
    }
  }
  return { missing, kept };
}

function missingCobolDomains(files, plan) {
  const missing = [];
  const domains = files.map((f) => (f.match(/^cobol\/src\/([a-z0-9_]+)_core\.cob$/) || [])[1]).filter(Boolean);
  for (const d of domains) {
    const hasSuite = plan.db_suites.some((s) => s === `tests/db/${d}_db_tests.sh`);
    const hasCase = plan.table_cases.some((c) => c === `tests/cobol/cases/${d}.cases`);
    if (!hasSuite && !hasCase) missing.push(`cobol/src/${d}_core.cob`);
  }
  return missing;
}

function resolvePlan(files, base) {
  const suites = readListFile('scripts/ci/coverage-suites.txt');
  const modules = readListFile('scripts/ci/coverage-modules.txt');
  let result;
  try {
    result = planForFiles(files, { suites, modules });
  } catch (e) {
    result = fullPlan(`fallback: policy error: ${e && e.message ? e.message : e}`);
  }

  // Validate candidates against the tree; missing pairs cannot run.
  const { missing, kept } = collectMissing(result.plan, files);
  result.plan.db_suites = kept.db_suites;
  result.plan.table_cases = kept.table_cases;
  result.plan.node_files = kept.node_files;

  // A COBOL domain with neither suite nor case in the tree cannot be
  // selected: fail safe to full.
  const absent = missingCobolDomains(files, result.plan);

  const allMissing = [...missing, ...absent];
  if (allMissing.length || result.unmapped.length) {
    const unmapped = [...new Set([...result.unmapped, ...allMissing])].sort();
    const full = fullPlan(`fallback: unmapped path(s): ${unmapped.join(', ')}`);
    full.unmapped = unmapped;
    return { ...full, base, files };
  }
  return { ...result, base, files };
}

function loadChangeSet(args) {
  if (args.files !== null) {
    return {
      files: [...new Set(args.files.map((s) => String(s).trim()).filter(Boolean))].sort(),
      base: args.base,
    };
  }
  const base = args.base || process.env.PR_BASE_SHA || process.env.PUSH_BEFORE_SHA || null;
  const resolved = resolveBase(base || 'origin/main');
  if (!resolved) return { fallback: fullPlan('fallback: no git base available'), base: base || null, files: [] };
  const changed = changedFiles(resolved);
  if (changed === null) return { fallback: fullPlan('fallback: git diff failed'), base: resolved, files: [] };
  return { files: changed, base: resolved };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const enforce = bool(process.env.PLAN_ENFORCE);
  const event = String(process.env.EVENT_NAME || 'pull_request');
  const head = git(['rev-parse', 'HEAD']) || 'HEAD';
  const ctx = { out: args.out, githubOutput: args.githubOutput, json: args.json, enforce, event, head };

  if (args.fallbackFull) {
    emit({ ...fullPlan('fallback: explicit --fallback-full'), base: null, files: [] }, ctx);
    return;
  }

  const changeSet = loadChangeSet(args);
  if (changeSet.fallback) {
    emit({ ...changeSet.fallback, base: changeSet.base, files: changeSet.files }, ctx);
    return;
  }

  if (bool(process.env.HAS_CI_FULL_LABEL)) {
    emit({ ...fullPlan('fallback: ci:full label'), base: changeSet.base, files: changeSet.files }, ctx);
    return;
  }

  emit(resolvePlan(changeSet.files, changeSet.base), ctx);
}

if (import.meta.url === `file://${process.argv[1]}`) main();
