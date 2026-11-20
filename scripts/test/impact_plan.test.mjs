// Unit tests for scripts/ci/impact-plan.mjs and impact-audit.mjs (PR-01).
// CLI-level: fallback safety, effective-output parity with the legacy CI,
// enforcement mapping, and the advisory audit. No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const PLAN = path.join(ROOT, 'scripts', 'ci', 'impact-plan.mjs');
const AUDIT = path.join(ROOT, 'scripts', 'ci', 'impact-audit.mjs');

function runPlan(args, env = {}) {
  try {
    const stdout = execFileSync(process.execPath, [PLAN, ...args], {
      encoding: 'utf8',
      cwd: ROOT,
      timeout: 120000,
      env: { ...process.env, ...env },
    });
    return { stdout, status: 0 };
  } catch (e) {
    return { stdout: String((e && e.stdout) || ''), stderr: String((e && e.stderr) || e), status: e?.status ?? 1 };
  }
}

function docOf(r) {
  return JSON.parse(r.stdout);
}

const LEGACY_PR = {
  EVENT_NAME: 'pull_request',
  PLAN_ENFORCE: 'false',
  DOCS_ONLY: 'false',
  DOCKER_RELEVANT: 'false',
  DOCKER_DEFINITION: 'false',
  COVERAGE_RELEVANT: 'false',
  DB_OPS_RELEVANT: 'false',
  SELECT_MODE: 'full',
  SELECT_DB_SUITES: '',
  HAS_CI_FULL_LABEL: 'false',
};

test('docs change plans docs-only', () => {
  const r = runPlan(['--files', 'docs/CI.md'], LEGACY_PR);
  assert.equal(r.status, 0);
  const d = docOf(r);
  assert.equal(d.mode, 'docs');
  assert.equal(d.plan.lint, 'docs');
  assert.equal(d.plan.build, false);
  assert.equal(d.plan.test, 'none');
  assert.deepEqual(d.unmapped, []);
  assert.ok(d.would_skip.includes('build'));
  assert.ok(d.would_skip.includes('test'));
  assert.ok(!d.would_skip.includes('lint'));
});

test('static change plans static with no runtime', () => {
  const r = runPlan(['--files', 'manifest/modules.json', 'contracts/actions.yaml'], LEGACY_PR);
  assert.equal(r.status, 0);
  const d = docOf(r);
  assert.equal(d.mode, 'static');
  assert.equal(d.plan.test, 'none');
  assert.equal(d.plan.db, 'none');
  assert.equal(d.plan.gateway_coverage, false);
  assert.equal(d.plan.cobol_coverage, false);
});

test('cobol domain plans a selected run', () => {
  const r = runPlan(['--files', 'cobol/src/loan_core.cob'], LEGACY_PR);
  assert.equal(r.status, 0);
  const d = docOf(r);
  assert.equal(d.mode, 'code');
  assert.equal(d.plan.test, 'selected');
  assert.equal(d.plan.db, 'selected');
  assert.deepEqual(d.plan.db_suites, ['tests/db/loan_db_tests.sh']);
  assert.deepEqual(d.plan.table_cases, ['tests/cobol/cases/loan.cases']);
  assert.ok(!d.would_skip.includes('db-selected'));
  assert.ok(d.would_skip.includes('db-shards'));
});

test('unknown path falls back to full with unmapped', () => {
  const r = runPlan(['--files', 'totally/unknown.xyz'], LEGACY_PR);
  assert.equal(r.status, 0);
  const d = docOf(r);
  assert.equal(d.mode, 'full');
  assert.deepEqual(d.unmapped, ['totally/unknown.xyz']);
  assert.equal(d.plan.test, 'full');
  assert.equal(d.plan.db, 'full');
});

test('ci:full label forces full', () => {
  const r = runPlan(['--files', 'docs/CI.md'], { ...LEGACY_PR, HAS_CI_FULL_LABEL: 'true' });
  assert.equal(r.status, 0);
  const d = docOf(r);
  assert.equal(d.mode, 'full');
  assert.match(d.reason, /ci:full/);
});

test('--fallback-full writes every output as full', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'impact-'));
  try {
    const gh = path.join(dir, 'github_output');
    writeFileSync(gh, '');
    const r = runPlan(['--fallback-full', '--github-output', gh], LEGACY_PR);
    assert.equal(r.status, 0);
    const lines = readFileSync(gh, 'utf8').trim().split('\n');
    const out = Object.fromEntries(lines.map((l) => l.split('=')));
    const keys = [
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
    for (const k of keys) assert.ok(k in out, `missing output ${k}`);
    assert.equal(out.plan_mode, 'full');
    assert.equal(out.eff_test, 'full');
    assert.equal(out.eff_db, 'full');
    assert.equal(out.eff_aggregate, 'true');
    assert.equal(out.eff_db_snapshot, 'true');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('shadow eff reproduces the legacy PR behavior', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'impact-'));
  try {
    const gh = path.join(dir, 'github_output');
    writeFileSync(gh, '');
    const r = runPlan(['--files', 'cobol/src/loan_core.cob', '--github-output', gh], LEGACY_PR);
    assert.equal(r.status, 0);
    const out = Object.fromEntries(
      readFileSync(gh, 'utf8')
        .trim()
        .split('\n')
        .map((l) => l.split('=')),
    );
    // Legacy: PR runs everything except docker without a definition change.
    assert.equal(out.eff_build, 'true');
    assert.equal(out.eff_test, 'full');
    assert.equal(out.eff_db, 'full');
    assert.equal(out.eff_gateway_coverage, 'true');
    assert.equal(out.eff_aggregate, 'true');
    assert.equal(out.eff_db_snapshot, 'true');
    assert.equal(out.eff_docker, 'false');
    // The plan itself stays selective (shadow only).
    assert.equal(out.plan_test, 'selected');
    assert.equal(out.plan_db, 'selected');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('shadow eff reproduces the legacy push behavior', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'impact-'));
  try {
    const gh = path.join(dir, 'github_output');
    writeFileSync(gh, '');
    const r = runPlan(['--files', 'cobol/src/loan_core.cob', '--github-output', gh], {
      ...LEGACY_PR,
      EVENT_NAME: 'push',
      DOCS_ONLY: 'false',
      DB_OPS_RELEVANT: 'false',
    });
    assert.equal(r.status, 0);
    const out = Object.fromEntries(
      readFileSync(gh, 'utf8')
        .trim()
        .split('\n')
        .map((l) => l.split('=')),
    );
    assert.equal(out.eff_test, 'none');
    assert.equal(out.eff_db, 'none');
    assert.equal(out.eff_gateway_coverage, 'false');
    assert.equal(out.eff_schema_drift, 'false');
    assert.equal(out.eff_aggregate, 'false');
    assert.equal(out.eff_db_snapshot, 'false');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('shadow eff reproduces the legacy dispatch behavior', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'impact-'));
  try {
    const gh = path.join(dir, 'github_output');
    writeFileSync(gh, '');
    const r = runPlan(['--files', 'docs/CI.md', '--github-output', gh], {
      ...LEGACY_PR,
      EVENT_NAME: 'workflow_dispatch',
    });
    assert.equal(r.status, 0);
    const out = Object.fromEntries(
      readFileSync(gh, 'utf8')
        .trim()
        .split('\n')
        .map((l) => l.split('=')),
    );
    assert.equal(out.eff_gateway_coverage, 'true');
    assert.equal(out.eff_schema_drift, 'true');
    assert.equal(out.eff_db_snapshot, 'true');
    assert.equal(out.eff_test, 'none');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('enforced eff follows the plan', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'impact-'));
  try {
    const gh = path.join(dir, 'github_output');
    writeFileSync(gh, '');
    const r = runPlan(['--files', 'docs/CI.md', '--github-output', gh], {
      ...LEGACY_PR,
      PLAN_ENFORCE: 'true',
    });
    assert.equal(r.status, 0);
    const out = Object.fromEntries(
      readFileSync(gh, 'utf8')
        .trim()
        .split('\n')
        .map((l) => l.split('=')),
    );
    assert.equal(out.eff_lint, 'docs');
    assert.equal(out.eff_build, 'false');
    assert.equal(out.eff_test, 'none');
    assert.equal(out.eff_aggregate, 'false');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

function runAudit(planObj, jobs) {
  const dir = mkdtempSync(path.join(tmpdir(), 'audit-'));
  try {
    const planPath = path.join(dir, 'plan.json');
    const outPath = path.join(dir, 'audit.json');
    writeFileSync(planPath, JSON.stringify(planObj));
    let stdout = '';
    let status = 0;
    try {
      stdout = execFileSync(
        process.execPath,
        [AUDIT, '--plan', planPath, '--jobs-json', JSON.stringify(jobs), '--out', outPath],
        {
          encoding: 'utf8',
          cwd: ROOT,
          timeout: 60000,
        },
      );
    } catch (e) {
      stdout = String((e && e.stdout) || '');
      status = e?.status ?? 1;
    }
    const audit = JSON.parse(readFileSync(outPath, 'utf8'));
    return { audit, stdout, status };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('audit passes when would-skip jobs did not fail', () => {
  const { audit, status } = runAudit(
    { mode: 'static', would_skip: ['build', 'test'], unmapped: [] },
    { build: { result: 'success' }, test: { result: 'skipped' } },
  );
  assert.equal(status, 0);
  assert.equal(audit.ok, true);
  assert.deepEqual(audit.false_negatives, []);
});

test('audit flags a failed would-skip job', () => {
  const { audit, status } = runAudit(
    { mode: 'static', would_skip: ['build', 'test'], unmapped: [] },
    { build: { result: 'failure' }, test: { result: 'success' } },
  );
  assert.equal(status, 0);
  assert.equal(audit.ok, false);
  assert.deepEqual(audit.false_negatives, ['build']);
});

test('audit requires its inputs', () => {
  let status = 0;
  try {
    execFileSync(process.execPath, [AUDIT, '--plan', '/nonexistent/plan.json', '--jobs-json', '{}'], {
      encoding: 'utf8',
      cwd: ROOT,
      timeout: 60000,
    });
  } catch (e) {
    status = e?.status ?? 1;
  }
  assert.equal(status, 2);
});
