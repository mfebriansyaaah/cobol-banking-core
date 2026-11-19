// CI weekly health report (Phase 4).
//
// Reads ci_metrics.mjs JSON (PR + push) and `gh run list --json` arrays for
// scheduled workflows, evaluates the SLOs in docs/CI_SLO.md, and renders a
// Markdown report with a `## Status` block first so scripts/ci/ci_health_issue.sh
// can parse it without depending on table order.
//
// Usage:
//   node scripts/ci/ci_weekly_report.mjs --pr PR.json --push PUSH.json
//     --nightly N.json --coverage C.json --mutation M.json [--cost COST.json]
//     [--budget 10000] [--out summary.md]
// Exit 0 on success (report written); exit 2 on usage/parse error. SLO
// breaches do NOT affect the exit code; the workflow opens the issue.
import { appendFileSync, readFileSync, writeFileSync } from 'node:fs';

const argv = process.argv.slice(2);

function hasFlag(name) {
  return argv.includes(name);
}

export function parseArgs(args = argv) {
  const get = (name) => {
    const i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  };
  const budgetRaw = get('--budget');
  const budget = budgetRaw === null ? 10000 : Math.max(1, parseInt(budgetRaw, 10) || 10000);
  return {
    pr: get('--pr'),
    push: get('--push'),
    nightly: get('--nightly'),
    coverage: get('--coverage'),
    mutation: get('--mutation'),
    cost: get('--cost'),
    budget,
    out: get('--out'),
  };
}

export function readJson(file, label) {
  try {
    return JSON.parse(readFileSync(file, 'utf8'));
  } catch (e) {
    throw new Error(`cannot read ${label} JSON ${file}: ${e.message}`, { cause: e });
  }
}

export function readRuns(file) {
  const data = readJson(file, 'scheduled runs');
  const arr = Array.isArray(data) ? data : [];
  // Ignore in-progress runs (conclusion null) so a running workflow never
  // flips the report.
  return arr.filter((r) => r && r.conclusion !== null && r.conclusion !== undefined);
}

/** Scheduled success stats; null pct when there is no finished run. */
export function scheduledStats(runs) {
  const finished = (Array.isArray(runs) ? runs : []).filter(
    (r) => r && r.conclusion !== null && r.conclusion !== undefined,
  );
  const total = finished.length;
  const success = finished.filter((r) => r.conclusion === 'success').length;
  if (!total) return { total: 0, success: 0, pct: null };
  return { total, success, pct: (100 * success) / total };
}

export function fmtPct(v) {
  if (v === null || v === undefined || !Number.isFinite(v)) return 'n/a';
  return `${v.toFixed(1)}%`;
}

export function fmtMin(sec) {
  if (sec === null || sec === undefined || !Number.isFinite(sec)) return 'n/a';
  return `${(sec / 60).toFixed(1)} min`;
}

/**
 * Evaluate SLOs. Returns { overall, reasons, checks } where each check is
 * { metric, measured, target, status, note }.
 */
export function wallStatus(sec) {
  if (!Number.isFinite(sec)) return { measured: 'n/a', status: 'WARN', note: 'no data' };
  if (sec <= 720) return { measured: fmtMin(sec), status: 'PASS', note: '' };
  return { measured: fmtMin(sec), status: 'FAIL', note: '' };
}

export function failureRateStatus(obj, limit) {
  if (!obj || !Number.isFinite(obj.failure_rate_pct)) {
    return { measured: 'n/a', status: 'WARN', note: 'no data' };
  }
  const runs = obj.runs ?? 0;
  if (runs < 10) {
    return { measured: fmtPct(obj.failure_rate_pct), status: 'WARN', note: `LOW SAMPLE (${runs} runs)` };
  }
  if (obj.failure_rate_pct <= limit) {
    return { measured: fmtPct(obj.failure_rate_pct), status: 'PASS', note: '' };
  }
  return { measured: fmtPct(obj.failure_rate_pct), status: 'FAIL', note: '' };
}

export function cascadedStatus(pr) {
  const c = pr && typeof pr.cascaded_failures === 'number' ? pr.cascaded_failures : null;
  if (c === null) return { measured: 'n/a', status: 'WARN', note: 'no data' };
  if (c === 0) return { measured: '0', status: 'PASS', note: '' };
  return {
    measured: String(c),
    status: 'FAIL',
    note: `primary ${fmtPct(pr.primary_failure_rate_pct)} vs raw ${fmtPct(pr.failure_rate_pct)}`,
  };
}

export function scheduledCheck(stats, target) {
  const total = stats ? stats.total : 0;
  if (!total) return { measured: 'n/a', status: 'WARN', note: 'no finished runs', target };
  const measured = `${fmtPct(stats.pct)} (${stats.success}/${stats.total})`;
  if (total < 5) return { measured, status: 'WARN', note: 'LOW SAMPLE', target: `>= ${target}%` };
  if (stats.pct >= target) return { measured, status: 'PASS', note: '', target: `>= ${target}%` };
  return { measured, status: 'FAIL', note: '', target: `>= ${target}%` };
}

export function jobMinStatus(obj, limit) {
  if (!obj || !Number.isFinite(obj.job_minutes_p50)) {
    return { measured: 'n/a', status: 'WARN', note: 'no data' };
  }
  const runs = obj.runs ?? 0;
  if (runs < 10) {
    return { measured: `${obj.job_minutes_p50} job-min`, status: 'WARN', note: `LOW SAMPLE (${runs} runs)` };
  }
  if (obj.job_minutes_p50 <= limit) {
    return { measured: `${obj.job_minutes_p50} job-min`, status: 'PASS', note: '' };
  }
  return { measured: `${obj.job_minutes_p50} job-min`, status: 'FAIL', note: '' };
}

export function wasteStatus(obj) {
  if (!obj || !Number.isFinite(obj.failed_run_waste_pct)) {
    return { measured: 'n/a', status: 'WARN', note: 'no data' };
  }
  const runs = obj.runs ?? 0;
  if (runs < 10) {
    return { measured: fmtPct(obj.failed_run_waste_pct), status: 'WARN', note: `LOW SAMPLE (${runs} runs)` };
  }
  if (obj.failed_run_waste_pct <= 8) {
    return { measured: fmtPct(obj.failed_run_waste_pct), status: 'PASS', note: '' };
  }
  return { measured: fmtPct(obj.failed_run_waste_pct), status: 'FAIL', note: '' };
}

export function monthlyStatus(cost, budget) {
  const target = `<= ${budget} job-min`;
  if (!cost || cost.error || !Number.isFinite(cost.total_job_minutes)) {
    return { measured: 'n/a', status: 'WARN', note: 'LOW CONFIDENCE', target };
  }
  if (cost.total_job_minutes <= budget) {
    return { measured: `${cost.total_job_minutes} job-min`, status: 'PASS', note: '', target };
  }
  return { measured: `${cost.total_job_minutes} job-min`, status: 'FAIL', note: '', target };
}

export function evaluateSLO({ pr, push, nightly, coverage, mutation, cost = null, budget = 10000 }) {
  const checks = [];
  const reasons = [];

  const pushCheck = (metric, measured, target, status, note = '') => {
    checks.push({ metric, measured, target, status, note });
    if (status === 'FAIL') reasons.push(`${metric}: ${measured} (target ${target})${note ? ` — ${note}` : ''}`);
    else if (status === 'WARN') {
      reasons.push(`${metric}: ${measured} (target ${target}, warning)${note ? ` — ${note}` : ''}`);
    }
  };

  const wall = wallStatus(pr && pr.wall_clock_p50_sec);
  pushCheck('PR p50 wall clock', wall.measured, '<= 12 min', wall.status, wall.note);

  const prRate = failureRateStatus(pr, 25);
  pushCheck('PR failure rate', prRate.measured, '<= 25%', prRate.status, prRate.note);

  const pushRate = failureRateStatus(push, 10);
  pushCheck('Push failure rate', pushRate.measured, '<= 10%', pushRate.status, pushRate.note);

  const cascaded = cascadedStatus(pr);
  pushCheck('PR cascaded failures', cascaded.measured, '0', cascaded.status, cascaded.note);

  const prMin = jobMinStatus(pr, 22);
  pushCheck('PR p50 job-min', prMin.measured, '<= 22 job-min', prMin.status, prMin.note);

  const pushMin = jobMinStatus(push, 18);
  pushCheck('Push p50 job-min', pushMin.measured, '<= 18 job-min', pushMin.status, pushMin.note);

  const waste = wasteStatus(pr);
  pushCheck('PR failed-run waste', waste.measured, '<= 8%', waste.status, waste.note);

  const monthly = monthlyStatus(cost, budget);
  pushCheck('Monthly job-min (30d)', monthly.measured, monthly.target, monthly.status, monthly.note);

  for (const [label, stats, target] of [
    ['Nightly success', nightly, 90],
    ['Coverage scheduled success', coverage, 90],
    ['Mutation scheduled success', mutation, 80],
  ]) {
    const s = scheduledCheck(stats, target);
    pushCheck(label, s.measured, s.target, s.status, s.note);
  }

  const overall = checks.some((c) => c.status === 'FAIL')
    ? 'FAIL'
    : checks.some((c) => c.status === 'WARN')
      ? 'WARN'
      : 'PASS';
  return { overall, reasons, checks };
}

export function cell(v) {
  if (v === null || v === undefined || v === '') return 'n/a';
  return String(v);
}

export function statusBlock(evaluated, generatedAt) {
  return [
    '# CI Health Report',
    '',
    `Generated: ${generatedAt}`,
    '',
    '## Status',
    '',
    `- Overall: ${evaluated.overall}`,
    `- Reasons: ${evaluated.reasons.length ? evaluated.reasons.join('; ') : 'none'}`,
    '',
  ];
}

export function wasteRows(pr, push) {
  return [
    `| job-min total | ${cell(pr && pr.job_minutes_total)} | ${cell(push && push.job_minutes_total)} |`,
    `| job-min failed | ${cell(pr && pr.job_minutes_failed)} | ${cell(push && push.job_minutes_failed)} |`,
    `| failed-run waste | ${cell(pr && fmtPct(pr.failed_run_waste_pct))} | ${cell(push && fmtPct(push.failed_run_waste_pct))} |`,
  ];
}

export function prPushTable(pr, push) {
  return [
    '## PR / push (ci_metrics)',
    '',
    '| Metric | PR | Push |',
    '|---|---|---|',
    `| runs considered | ${cell(pr && pr.runs)} | ${cell(push && push.runs)} |`,
    `| wall p50 | ${cell(pr && pr.wall_clock_p50_human)} (${cell(pr && pr.job_minutes_p50)} job-min) | ${cell(push && push.wall_clock_p50_human)} (${cell(push && push.job_minutes_p50)} job-min) |`,
    `| failure rate | ${cell(pr && fmtPct(pr.failure_rate_pct))} | ${cell(push && fmtPct(push.failure_rate_pct))} |`,
    `| primary failure rate | ${cell(pr && fmtPct(pr.primary_failure_rate_pct))} | ${cell(push && fmtPct(push.primary_failure_rate_pct))} |`,
    `| cascaded failures | ${cell(pr && pr.cascaded_failures)} | ${cell(push && push.cascaded_failures)} |`,
    ...wasteRows(pr, push),
    '',
  ];
}

export function failedJobsSection(pr) {
  const failedJobs = (pr && pr.primary_failed_jobs) || {};
  const names = Object.keys(failedJobs).sort((a, b) => failedJobs[b] - failedJobs[a]);
  if (!names.length) return [];
  return ['## PR primary failures by job', '', ...names.map((n) => `- ${n}: ${failedJobs[n]}`), ''];
}

export function scheduledTable(nightly, coverage, mutation) {
  const row = (label, stats, target) =>
    `| ${label} | ${stats.success}/${stats.total} | ${fmtPct(stats.pct)} | >= ${target}% |`;
  return [
    '## Scheduled success',
    '',
    '| Workflow | Success | Rate | Target |',
    '|---|---|---|---|',
    row('nightly.yml', nightly, 90),
    row('coverage.yml', coverage, 90),
    row('mutation.yml', mutation, 80),
    '',
  ];
}

export function sloTable(checks) {
  return [
    '## SLO checks',
    '',
    '| Metric | Measured | Target | Status |',
    '|---|---|---|---|',
    ...checks.map((c) => `| ${c.metric} | ${c.measured} | ${c.target} | ${c.status} |`),
    '',
  ];
}

export function costSection(cost, budget) {
  if (!cost) return [];
  if (cost.error) return ['## Cost (30d)', '', `Cost data unavailable: ${cost.error} (LOW CONFIDENCE)`, ''];
  const names = Object.keys(cost.by_workflow || {}).sort((a, b) => cost.by_workflow[b] - cost.by_workflow[a]);
  return [
    '## Cost (30d)',
    '',
    `Budget: <= ${budget} job-min. Measured over ${cost.days} day(s) since ${cost.since} (${cost.runs} completed runs).`,
    '',
    '| Workflow | Job-min |',
    '|---|---:|',
    ...names.map((n) => `| ${n} | ${cost.by_workflow[n]} |`),
    `| total | ${cost.total_job_minutes} |`,
    '',
  ];
}

export function renderMarkdown({
  pr,
  push,
  nightly,
  coverage,
  mutation,
  evaluated,
  generatedAt,
  cost = null,
  budget = 10000,
}) {
  const lines = [
    ...statusBlock(evaluated, generatedAt),
    ...prPushTable(pr, push),
    ...failedJobsSection(pr),
    ...scheduledTable(nightly, coverage, mutation),
    ...costSection(cost, budget),
    ...sloTable(evaluated.checks),
  ];
  return `${lines.join('\n')}\n`;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (hasFlag('--help') || hasFlag('-h')) {
    console.log(
      'usage: ci_weekly_report.mjs --pr PR.json --push PUSH.json --nightly N.json --coverage C.json --mutation M.json [--cost COST.json] [--budget 10000] [--out summary.md]',
    );
    process.exit(0);
  }
  const args = parseArgs();
  const missing = ['pr', 'push', 'nightly', 'coverage', 'mutation'].filter((k) => !args[k]);
  if (missing.length) {
    console.error(`usage: missing --${missing.join(' --')}`);
    process.exit(2);
  }
  let pr;
  let push;
  let nightlyRuns;
  let coverageRuns;
  let mutationRuns;
  let cost = null;
  try {
    pr = readJson(args.pr, 'PR metrics');
    push = readJson(args.push, 'push metrics');
    nightlyRuns = readRuns(args.nightly);
    coverageRuns = readRuns(args.coverage);
    mutationRuns = readRuns(args.mutation);
    if (args.cost) {
      try {
        cost = readJson(args.cost, 'cost');
      } catch (e) {
        console.error(`warning: ${e.message} (LOW CONFIDENCE)`);
        cost = { error: e.message };
      }
    }
  } catch (e) {
    console.error(`FAIL: ${e.message}`);
    process.exit(2);
  }
  const nightly = scheduledStats(nightlyRuns);
  const coverage = scheduledStats(coverageRuns);
  const mutation = scheduledStats(mutationRuns);
  const evaluated = evaluateSLO({ pr, push, nightly, coverage, mutation, cost, budget: args.budget });
  const generatedAt = new Date().toISOString();
  const text = renderMarkdown({
    pr,
    push,
    nightly,
    coverage,
    mutation,
    evaluated,
    generatedAt,
    cost,
    budget: args.budget,
  });
  process.stdout.write(text);
  if (args.out) writeFileSync(args.out, text);
  const summary = process.env.GITHUB_STEP_SUMMARY;
  if (summary) {
    try {
      appendFileSync(summary, text);
    } catch {
      // best effort; the artifact still holds the report.
    }
  }
  process.exit(0);
}
