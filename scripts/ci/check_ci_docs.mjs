// CI docs check: docs/CI.md must stay in sync with .github/workflows/*.yml.
//
// Rules:
//   1. Every job id from every workflow appears in docs/CI.md.
//   2. Every display name appears in docs/CI.md. For matrix names containing
//      ${{ ... }}, only the prefix before ${{ is required (e.g. "db shard").
//      Display-name matching is case-insensitive; job-id matching is exact.
//   3. The required-checks list contains lint, build, test, coverage,
//      db aggregate, coverage-pr.
//   4. If docker-build exists, docs/CI.md mentions it (covered by 1, kept
//      explicit for a clearer error).
//   5. If docs/CI_SLO.md exists, docs/CI.md must link it.
//
// Usage: node scripts/ci/check_ci_docs.mjs [--root DIR]
// Exit: 0 ok, 1 drift, 2 usage error.
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
    console.log('usage: check_ci_docs.mjs [--root DIR]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
root = path.resolve(root);

const WORKFLOWS = ['ci.yml', 'nightly.yml', 'coverage.yml', 'codeql.yml', 'mutation.yml', 'ci-report.yml'];

function loadJobs() {
  const files = WORKFLOWS.map((f) => path.join(root, '.github', 'workflows', f)).filter((f) => existsSync(f));
  const script = `
import json, sys, yaml
out = {}
for f in sys.argv[1:]:
    try:
        with open(f) as fh:
            doc = yaml.safe_load(fh.read())
    except Exception as e:
        out[f] = {"__error__": str(e)}
        continue
    out[f] = doc.get('jobs') or {}
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

const docsByFile = loadJobs();
const failed = [];

const jobIds = new Set();
const displayNames = new Set();
for (const jobs of Object.values(docsByFile)) {
  if (!jobs || typeof jobs !== 'object' || jobs.__error__) {
    failed.push(`cannot parse workflow: ${JSON.stringify(jobs && jobs.__error__)}`);
    continue;
  }
  for (const [id, spec] of Object.entries(jobs)) {
    jobIds.add(id);
    if (spec && typeof spec.name === 'string' && spec.name.trim()) {
      displayNames.add(spec.name.trim());
    }
  }
}

const ciPath = path.join(root, 'docs', 'CI.md');
if (!existsSync(ciPath)) {
  console.error('FAIL: docs/CI.md is missing');
  process.exit(1);
}
const ciText = readFileSync(ciPath, 'utf8');
const ciLower = ciText.toLowerCase();

for (const id of [...jobIds].sort()) {
  if (!ciText.includes(id)) {
    failed.push(`docs/CI.md lacks job id '${id}' (add it to the trigger matrix or job table)`);
  }
}

for (const name of [...displayNames].sort()) {
  const marker = name.includes('${{') ? name.slice(0, name.indexOf('${{')).trim() : name;
  if (!marker) continue;
  if (!ciLower.includes(marker.toLowerCase())) {
    failed.push(`docs/CI.md lacks display name '${marker}' (from job name '${name}')`);
  }
}

for (const check of ['lint', 'build', 'test', 'coverage', 'db aggregate', 'coverage-pr']) {
  if (!ciText.includes(check)) {
    failed.push(`docs/CI.md lacks required check '${check}'`);
  }
}

if ([...jobIds].includes('docker-build') && !ciText.includes('docker-build')) {
  failed.push("docs/CI.md lacks 'docker-build' (job exists in ci.yml)");
}

if (existsSync(path.join(root, 'docs', 'CI_SLO.md')) && !ciText.includes('CI_SLO')) {
  failed.push('docs/CI.md must link docs/CI_SLO.md when the SLO file exists');
}

if (failed.length) {
  for (const f of failed) console.error(`FAIL: ${f}`);
  console.error('\nCI docs drifted from workflows (see docs/CI.md).');
  process.exit(1);
}
console.log('OK: docs/CI.md matches workflows');
