// CI contract check (T-006).
//
// Verifies the workflow triggers and required jobs that the 9/10 gate needs.
// Parsing uses Python 3 + PyYAML (already installed for yamllint) so no new
// npm dependency is required and nested YAML is not regex-parsed.
//
// Modes:
//   enforced (default): ci.yml must have pull_request + push to main;
//     nightly.yml and coverage.yml must have schedule; codeql.yml must have
//     schedule; ci.yml must contain the required jobs.
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
const REQUIRED_JOBS = ['lint', 'build', 'test', 'db-shards', 'db-aggregate', 'coverage'];

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
    const stdout = execFileSync(
      'python3',
      ['-c', script, ...files],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 60000 },
    );
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
if (!('push' in ciOn)) failed.push('ci.yml lacks push trigger');
else if (!pushBranches(ciOn).includes('main')) {
  failed.push(`ci.yml push branches must include main (got: ${pushBranches(ciOn).join(',')})`);
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

if (failed.length) {
  for (const f of failed) console.error(`FAIL: ${f}`);
  console.error('\nCI contract violated (see docs/CI.md).');
  process.exit(1);
}
console.log('OK: CI triggers and required jobs match docs/CI.md');
