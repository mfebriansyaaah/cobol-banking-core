// CI contract check (T-006, CI-001).
//
// Verifies the workflow triggers, required jobs, and hardening invariants
// that branch protection and supply-chain policy depend on.
// Parsing uses Python 3 + PyYAML (already installed for yamllint) so no new
// npm dependency is required and nested YAML is not regex-parsed.
//
// Modes:
//   enforced (default): ci.yml must have pull_request + push to main;
//     nightly.yml and coverage.yml must have schedule; codeql.yml must have
//     schedule; ci.yml must contain the required jobs; every job in every
//     workflow must have timeout-minutes and SHA-pinned actions; every
//     workflow must declare permissions; ci.yml display names must match
//     GitHub check-run names; db-shards matrix must agree with the shard
//     runner and the aggregate step.
//   parked: if docs/ci-parked.md exists, it must have valid front matter
//     (owner, reason, expires YYYY-MM-DD, alternative_gate) and must not be
//     expired. A valid parked file relaxes the trigger requirements.
//
// Usage:
//   node scripts/check_ci_contract.mjs [--root DIR]
// Exit: 0 ok, 1 contract violation, 2 usage error.
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--root') {
    root = args[i + 1] ?? root;
    i += 1;
  } else if (a === '--help' || a === '-h') {
    console.log('usage: check_ci_contract.mjs [--root DIR]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
root = path.resolve(root);

const WORKFLOWS = ['ci.yml', 'nightly.yml', 'coverage.yml', 'codeql.yml'];
const REQUIRED_JOBS = ['lint', 'build', 'test', 'db-shards', 'db-aggregate', 'coverage', 'coverage-pr'];

// GitHub matches check runs by display name (job `name:`), not job ID.
// PR #510 was blocked by requiring `db-aggregate` (hyphen) instead of
// `db aggregate` (space). Enforce the exact names here.
const EXPECTED_JOB_NAMES = {
  lint: 'lint',
  build: 'build',
  test: 'test',
  'db-shards': /^db shard /,
  'db-aggregate': 'db aggregate',
  coverage: 'coverage',
  'coverage-pr': 'coverage-pr',
};

function loadWorkflows() {
  const files = WORKFLOWS.map((f) => path.join(root, '.github', 'workflows', f));
  const script = `
import json, sys, yaml
out = {}
for f in sys.argv[1:]:
    try:
        with open(f) as fh:
            out[f] = yaml.safe_load(fh.read())
    except Exception as e:
        out[f] = {"__error__": str(e)}
print(json.dumps(out))
`;
  try {
    const stdout = execFileSync('python3', ['-c', script, ...files], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: 60000,
    });
    return JSON.parse(stdout);
  } catch (e) {
    console.error(`FAIL: cannot parse workflows (python3+yaml required): ${e.message}`);
    process.exit(2);
  }
}

function onOf(doc) {
  // PyYAML parses `on:` as boolean true key in YAML 1.1; also accept 'on'.
  if (!doc || typeof doc !== 'object') return {};
  if (doc.on !== undefined) return doc.on;
  if (doc.true !== undefined) return doc.true;
  return {};
}

function asList(v) {
  if (v === undefined || v === null) return [];
  return Array.isArray(v) ? v : [v];
}

function pushBranches(on) {
  const push = on.push;
  if (!push) return [];
  if (typeof push === 'object' && push.branches) return asList(push.branches);
  return ['(any)'];
}

function pushBranchesIgnore(on) {
  const push = on.push;
  if (!push || typeof push !== 'object') return [];
  if (push['branches-ignore']) return asList(push['branches-ignore']);
  return [];
}

function schedules(on) {
  return asList(on.schedule).map((s) => (s && s.cron ? String(s.cron) : ''));
}

function parkedMode() {
  const p = path.join(root, 'docs', 'ci-parked.md');
  if (!existsSync(p)) return { parked: false };
  const src = readFileSync(p, 'utf8');
  const m = src.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return { parked: true, error: 'docs/ci-parked.md has no YAML front matter' };
  const fields = {};
  for (const line of m[1].split('\n')) {
    const mm = line.match(/^([a-z_]+):\s*(.+)\s*$/);
    if (mm) fields[mm[1]] = mm[2].trim();
  }
  for (const k of ['owner', 'reason', 'expires', 'alternative_gate']) {
    if (!fields[k]) return { parked: true, error: `docs/ci-parked.md missing field: ${k}` };
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fields.expires)) {
    return { parked: true, error: `docs/ci-parked.md expires is not YYYY-MM-DD: ${fields.expires}` };
  }
  const today = new Date().toISOString().slice(0, 10);
  if (fields.expires < today) {
    return { parked: true, error: `docs/ci-parked.md expired on ${fields.expires} (today ${today})` };
  }
  return { parked: true, fields };
}

const docs = loadWorkflows();
const byName = {};
for (const [file, doc] of Object.entries(docs)) {
  byName[path.basename(file)] = doc;
  if (doc && doc.__error__) {
    console.error(`FAIL: cannot parse ${file}: ${doc.__error__}`);
    process.exit(1);
  }
}

const park = parkedMode();
if (park.error) {
  console.error(`FAIL: ${park.error}`);
  process.exit(1);
}
if (park.parked) {
  console.log(
    `OK (parked): CI triggers parked until ${park.fields.expires} (owner ${park.fields.owner}); alternative: ${park.fields.alternative_gate}`,
  );
  process.exit(0);
}

const failed = [];
const ciOn = onOf(byName['ci.yml']);
if (!('pull_request' in ciOn)) failed.push('ci.yml lacks pull_request trigger');
else {
  // A pull_request trigger restricted to `closed` never runs on PR activity.
  const pr = ciOn.pull_request;
  if (pr && typeof pr === 'object' && pr.types) {
    const types = asList(pr.types);
    const active = types.filter((t) => t !== 'closed');
    if (types.length > 0 && active.length === 0) {
      failed.push('ci.yml pull_request trigger is restricted to closed (never runs on PRs)');
    }
  }
}
if (!('push' in ciOn)) failed.push('ci.yml lacks push trigger');
else {
  const ignored = pushBranchesIgnore(ciOn);
  if (ignored.includes('main')) {
    failed.push('ci.yml push branches-ignore must not include main (main would never trigger)');
  } else if (
    !pushBranches(ciOn).includes('main') &&
    !pushBranches(ciOn).includes('(any)') &&
    !pushBranches(ciOn).includes('*')
  ) {
    failed.push(`ci.yml push branches must include main (got: ${pushBranches(ciOn).join(',')})`);
  }
}

const nightlyCrons = schedules(onOf(byName['nightly.yml']));
if (!nightlyCrons.includes('0 2 * * *')) {
  failed.push(`nightly.yml lacks schedule 0 2 * * * (got: ${nightlyCrons.join(',') || 'none'})`);
}
const covCrons = schedules(onOf(byName['coverage.yml']));
if (!covCrons.includes('30 2 * * *')) {
  failed.push(`coverage.yml lacks schedule 30 2 * * * (got: ${covCrons.join(',') || 'none'})`);
}
const codeqlCrons = schedules(onOf(byName['codeql.yml']));
if (!codeqlCrons.length) failed.push('codeql.yml lacks schedule (expected weekly cron)');

const jobs = (byName['ci.yml'] && byName['ci.yml'].jobs) || {};
for (const j of REQUIRED_JOBS) {
  if (!(j in jobs)) failed.push(`ci.yml lacks required job: ${j}`);
}

// Display names: GitHub matches the check-run name, not the job ID.
for (const [id, expected] of Object.entries(EXPECTED_JOB_NAMES)) {
  if (!(id in jobs)) continue;
  const actual = jobs[id] && jobs[id].name;
  if (expected instanceof RegExp) {
    if (typeof actual !== 'string' || !expected.test(actual)) {
      failed.push(`ci.yml job '${id}' display name must match ${expected} (got: ${JSON.stringify(actual)})`);
    }
  } else if (actual !== expected) {
    failed.push(`ci.yml job '${id}' display name must be '${expected}' (got: ${JSON.stringify(actual)})`);
  }
}

// Every job in every workflow must declare a timeout.
for (const wf of WORKFLOWS) {
  const wjobs = (byName[wf] && byName[wf].jobs) || {};
  for (const [id, spec] of Object.entries(wjobs)) {
    const t = spec && spec['timeout-minutes'];
    if (typeof t !== 'number' || !Number.isFinite(t) || t <= 0) {
      failed.push(`${wf} job '${id}' lacks timeout-minutes (add timeout-minutes: <minutes>)`);
    }
  }
}

// Every remote action must be pinned to a 40-hex SHA. Local actions (`./...`)
// are exempt; everything else (including floating tags like @v4) fails.
const SHA_RE = /^[0-9a-f]{40}$/;
for (const wf of WORKFLOWS) {
  const wjobs = (byName[wf] && byName[wf].jobs) || {};
  for (const [id, spec] of Object.entries(wjobs)) {
    for (const step of (spec && spec.steps) || []) {
      if (!step || typeof step !== 'object' || !step.uses) continue;
      const uses = String(step.uses);
      if (uses.startsWith('./')) continue;
      const at = uses.lastIndexOf('@');
      const ref = at >= 0 ? uses.slice(at + 1) : '';
      if (!SHA_RE.test(ref)) {
        failed.push(`${wf} job '${id}' step uses '${uses}' must be pinned to a 40-hex SHA`);
      }
    }
  }
}

// Permissions: each workflow must declare them at the top level, or every
// job must declare them. write-all is never allowed.
for (const wf of WORKFLOWS) {
  const doc = byName[wf] || {};
  const top = doc.permissions;
  if (top === 'write-all') {
    failed.push(`${wf} must not use permissions: write-all`);
    continue;
  }
  if (top !== undefined && top !== null) continue;
  const wjobs = doc.jobs || {};
  const without = Object.entries(wjobs)
    .filter(([, spec]) => spec.permissions === undefined || spec.permissions === null)
    .map(([id]) => id);
  if (without.length > 0) {
    failed.push(`${wf} lacks permissions (add workflow-level permissions: contents: read)`);
  }
  for (const [id, spec] of Object.entries(wjobs)) {
    if (spec.permissions === 'write-all') {
      failed.push(`${wf} job '${id}' must not use permissions: write-all`);
    }
  }
}

// Shard consistency: the db-shards matrix, the DB_SHARD_COUNT the shard
// runner uses, and the aggregate step argument must agree.
(function checkShards() {
  const ciDoc = byName['ci.yml'] || {};
  const ciEnv = (ciDoc && ciDoc.env) || {};
  const shardJob = jobs['db-shards'];
  const aggJob = jobs['db-aggregate'];
  if (!shardJob || !aggJob) return;
  const matrix = shardJob.strategy && shardJob.strategy.matrix && shardJob.strategy.matrix.shard;
  const matrixLen = Array.isArray(matrix) ? matrix.length : 0;
  if (!matrixLen) {
    failed.push('ci.yml db-shards lacks strategy.matrix.shard');
    return;
  }
  // Precedence: inline `DB_SHARD_COUNT=n` in the run step, then the job env,
  // then the workflow env (the centralized single source of truth, CI-010).
  let shardCount = null;
  if (shardJob.env && shardJob.env.DB_SHARD_COUNT !== undefined) {
    shardCount = Number(shardJob.env.DB_SHARD_COUNT);
  }
  for (const step of shardJob.steps || []) {
    if (!step || typeof step !== 'object' || !step.run) continue;
    const m = String(step.run).match(/DB_SHARD_COUNT=(\d+)/);
    if (m) shardCount = Number(m[1]);
  }
  if ((shardCount === null || !Number.isFinite(shardCount)) && ciEnv.DB_SHARD_COUNT !== undefined) {
    shardCount = Number(ciEnv.DB_SHARD_COUNT);
  }
  if (shardCount === null || !Number.isFinite(shardCount)) {
    failed.push('ci.yml db-shards lacks DB_SHARD_COUNT (matrix runner must declare it)');
    return;
  }
  const resolveCountArg = (token) => {
    const bare = token.replace(/^["']|["']$/g, '');
    if (!/^\$/.test(bare)) return Number(bare);
    const name = bare.replace(/^\$\{?/, '').replace(/\}$/, '');
    const fromJob = aggJob.env && aggJob.env[name] !== undefined ? Number(aggJob.env[name]) : null;
    if (fromJob !== null && Number.isFinite(fromJob)) return fromJob;
    if (ciEnv[name] !== undefined) return Number(ciEnv[name]);
    return NaN;
  };
  let aggCount = null;
  for (const step of aggJob.steps || []) {
    if (!step || typeof step !== 'object' || !step.run) continue;
    const run = String(step.run);
    if (!run.includes('aggregate_shard_reports.sh')) continue;
    const parts = run.trim().split(/\s+/);
    const last = resolveCountArg(parts[parts.length - 1]);
    if (Number.isFinite(last)) aggCount = last;
  }
  if (aggCount === null) {
    failed.push('ci.yml db-aggregate lacks shard count argument (aggregate_shard_reports.sh <parts> <out> <n|$VAR>)');
    return;
  }
  if (matrixLen !== shardCount || matrixLen !== aggCount) {
    failed.push(
      `ci.yml shard count mismatch (matrix ${matrixLen}, DB_SHARD_COUNT ${shardCount}, aggregate ${aggCount})`,
    );
  }
})();

if (failed.length) {
  for (const f of failed) console.error(`FAIL: ${f}`);
  console.error('\nCI contract violated (see docs/CI.md).');
  process.exit(1);
}
console.log('OK: CI triggers and required jobs match docs/CI.md');
