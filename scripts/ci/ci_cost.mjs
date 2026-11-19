// CI monthly cost collector (Phase 3, cost observability).
//
// Totals billable job-minutes per workflow over the last N days using
// `gh api` (read-only). Billing counts each job rounded up to whole minutes,
// so this mirrors `jobMinutes()` in ci_metrics.mjs.
//
// Usage:
//   node scripts/ci/ci_cost.mjs --days 30 --repo OWNER/REPO [--json] [--out ci-cost.json]
// Exit 0 always (a gh failure prints {"error": ...} so the weekly report can
// mark LOW CONFIDENCE instead of failing the workflow). Never prints secrets.
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const argv = process.argv.slice(2);

export function parseCostArgs(args = argv) {
  const get = (name, def = null) => {
    const i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : def;
  };
  return {
    days: Math.max(1, parseInt(get('--days', '30'), 10) || 30),
    repo: get('--repo', null),
    json: args.includes('--json'),
    out: get('--out', null),
  };
}

function gh(args, timeout = 120000) {
  return execFileSync('gh', ['api', ...args], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout,
    maxBuffer: 64 * 1024 * 1024,
    env: { ...process.env },
  });
}

function detectRepo() {
  return execFileSync('gh', ['repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: 60000,
  }).trim();
}

const toMs = (iso) => {
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : null;
};

export function collectCost({ days, repo }) {
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  const sinceStr = since.toISOString().slice(0, 10);
  // Manual pagination: `gh api --paginate` concatenates raw bodies, which is
  // not valid JSON when there is more than one page.
  const all = [];
  for (let page = 1; page <= 10; page += 1) {
    const raw = gh([`repos/${repo}/actions/runs?per_page=100&page=${page}&created=>=${sinceStr}`]);
    const runs = JSON.parse(raw).workflow_runs || [];
    if (!runs.length) break;
    all.push(...runs);
    if (runs.length < 100) break;
  }
  const completed = all.filter((r) => r.status === 'completed' && r.conclusion);
  const byWorkflow = {};
  let total = 0;
  for (const r of completed) {
    const name = r.name || 'unknown';
    let minutes = 0;
    try {
      const jobsRaw = gh([`repos/${repo}/actions/runs/${r.id}/jobs?per_page=100`]);
      for (const j of JSON.parse(jobsRaw).jobs || []) {
        const start = toMs(j.started_at);
        const end = toMs(j.completed_at);
        if (start === null || end === null || end < start) continue;
        minutes += Math.ceil((end - start) / 60000);
      }
    } catch {
      continue;
    }
    total += minutes;
    byWorkflow[name] = (byWorkflow[name] || 0) + minutes;
  }
  return {
    days,
    since: sinceStr,
    repo,
    runs: completed.length,
    total_job_minutes: total,
    by_workflow: byWorkflow,
  };
}

export function renderCostHuman(cost) {
  const lines = [`CI cost: last ${cost.days} day(s) since ${cost.since} (${cost.runs} completed runs)`];
  const names = Object.keys(cost.by_workflow || {}).sort((a, b) => cost.by_workflow[b] - cost.by_workflow[a]);
  for (const n of names) lines.push(`  ${n}: ${cost.by_workflow[n]} job-min`);
  lines.push(`  total: ${cost.total_job_minutes} job-min`);
  return `${lines.join('\n')}\n`;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (argv.includes('--help') || argv.includes('-h')) {
    console.log('usage: ci_cost.mjs --days 30 --repo OWNER/REPO [--json] [--out FILE]');
    process.exit(0);
  }
  const { days, repo: repoArg, json, out } = parseCostArgs();
  const fail = (message) => {
    const payload = {
      error: message,
      days,
      since: null,
      repo: repoArg,
      runs: 0,
      total_job_minutes: null,
      by_workflow: {},
    };
    if (json) console.log(JSON.stringify(payload, null, 2));
    else console.log(`CI cost unavailable: ${message}`);
    if (out) writeFileSync(out, `${JSON.stringify(payload, null, 2)}\n`);
    process.exit(0);
  };
  let repo = repoArg;
  try {
    if (!repo) repo = detectRepo();
    const cost = collectCost({ days, repo });
    if (json) console.log(JSON.stringify(cost, null, 2));
    else console.log(renderCostHuman(cost));
    if (out) writeFileSync(out, `${JSON.stringify(cost, null, 2)}\n`);
  } catch (e) {
    fail(e.message);
  }
  process.exit(0);
}
