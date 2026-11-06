// CI metrics collector (CI-006).
//
// Repeatable before/after evidence for efficiency work: wall-clock p50,
// job-minute p50 (GitHub bills per job rounded up to whole minutes),
// failure rate, and per-job failure counts over recent CI runs.
//
// Data comes from `gh api` (read-only) or from --runs-json (offline,
// deterministic; used by scripts/test/ci_metrics.test.mjs).
//
// Usage:
//   node scripts/ci/ci_metrics.mjs --event pull_request|push [--limit N]
//       [--json] [--runs-json FILE] [--repo owner/repo]
// Exit 0 with the summary (JSON with --json, human-readable otherwise).
// Never prints secrets: only counts, names, and durations.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

export function median(values) {
  const nums = [...values].filter((v) => Number.isFinite(v)).sort((a, b) => a - b);
  if (!nums.length) return null;
  const mid = Math.floor(nums.length / 2);
  return nums.length % 2 ? nums[mid] : (nums[mid - 1] + nums[mid]) / 2;
}

const toMs = (iso) => {
  const t = Date.parse(iso);
  return Number.isFinite(t) ? t : null;
};

/** Billable minutes for one run: each job rounded up to a whole minute. */
export function jobMinutes(jobs) {
  return (jobs || []).reduce((sum, j) => {
    const start = toMs(j.started_at);
    const end = toMs(j.completed_at);
    if (start === null || end === null || end < start) return sum;
    return sum + Math.ceil((end - start) / 60000);
  }, 0);
}

/** Seconds from the first job start to the last job completion. */
export function runWallClockSec(jobs) {
  const starts = [];
  const ends = [];
  for (const j of jobs || []) {
    const s = toMs(j.started_at);
    const e = toMs(j.completed_at);
    if (s !== null) starts.push(s);
    if (e !== null) ends.push(e);
  }
  if (!starts.length || !ends.length) return null;
  const span = Math.max(...ends) - Math.min(...starts);
  return span >= 0 ? Math.round(span / 1000) : null;
}

const round1 = (v) => Math.round(v * 10) / 10;

/**
 * Summarize runs. Input: { event, runs } where each run is
 * { conclusion, jobs: [{ name, started_at, completed_at, conclusion }] }.
 * p50 values use at most `limit` most-recent successful runs; failure stats
 * cover every run with a terminal conclusion.
 */
export function summarize({ event, runs }, limit = 20) {
  const decided = (runs || []).filter((r) => r.conclusion === 'success' || r.conclusion === 'failure');
  const successful = decided.filter((r) => r.conclusion === 'success').slice(0, limit);
  const walls = successful.map((r) => runWallClockSec(r.jobs)).filter((v) => v !== null);
  const minutes = successful.map((r) => jobMinutes(r.jobs));
  const failed = decided.filter((r) => r.conclusion === 'failure');
  const failedJobs = {};
  for (const r of failed) {
    for (const j of r.jobs || []) {
      if (j.conclusion === 'failure') failedJobs[j.name] = (failedJobs[j.name] || 0) + 1;
    }
  }
  const wallP50 = median(walls);
  const human = wallP50 === null ? null : `${Math.floor(wallP50 / 60)}m ${wallP50 % 60}s`;
  return {
    event,
    runs: decided.length,
    successful_runs: successful.length,
    wall_clock_p50_sec: wallP50,
    wall_clock_p50_human: human,
    job_minutes_p50: minutes.length ? round1(median(minutes)) : null,
    failure_rate_pct: decided.length ? round1((100 * failed.length) / decided.length) : 0,
    failed_jobs: failedJobs,
  };
}

function gh(args, repo) {
  return execFileSync('gh', ['api', ...args], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: 120000,
    maxBuffer: 64 * 1024 * 1024,
    env: { ...process.env, GH_REPO: repo },
  });
}

function detectRepo() {
  return execFileSync('gh', ['repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: 60000,
  }).trim();
}

function fetchRuns({ repo, event, limit }) {
  // Note: per_page goes in the URL query string. Passing it via -f makes
  // `gh api` send a POST, which this read-only endpoint answers with 404.
  const raw = gh([`repos/${repo}/actions/runs?per_page=100`], repo);
  const all = JSON.parse(raw).workflow_runs || [];
  const matching = all
    .filter((r) => r.name === 'CI' && r.event === event && (r.conclusion === 'success' || r.conclusion === 'failure'))
    .sort((a, b) => (a.created_at < b.created_at ? 1 : -1));
  const wanted = [
    ...matching.filter((r) => r.conclusion === 'success').slice(0, limit),
    ...matching.filter((r) => r.conclusion === 'failure').slice(0, 40),
  ];
  const byId = new Map();
  for (const r of wanted) {
    const jobsRaw = gh([`repos/${repo}/actions/runs/${r.id}/jobs`, '--paginate'], repo);
    byId.set(
      r.id,
      (JSON.parse(jobsRaw).jobs || []).map((j) => ({
        name: j.name,
        started_at: j.started_at,
        completed_at: j.completed_at,
        conclusion: j.conclusion,
      })),
    );
  }
  return {
    event,
    runs: matching.filter((r) => byId.has(r.id)).map((r) => ({ conclusion: r.conclusion, jobs: byId.get(r.id) })),
  };
}

const argv = process.argv.slice(2);
if (import.meta.url === `file://${process.argv[1]}`) {
  const opt = (name, def) => {
    const i = argv.indexOf(name);
    return i >= 0 && argv[i + 1] !== undefined ? argv[i + 1] : def;
  };
  if (argv.includes('--help') || argv.includes('-h')) {
    console.log(
      'usage: ci_metrics.mjs --event pull_request|push [--limit N] [--json] [--runs-json FILE] [--repo owner/repo]',
    );
    process.exit(0);
  }
  const event = opt('--event', null);
  if (event !== 'pull_request' && event !== 'push') {
    console.error('usage: ci_metrics.mjs --event pull_request|push [--limit N] [--json] [--runs-json FILE]');
    process.exit(2);
  }
  const limit = Math.max(1, parseInt(opt('--limit', '20'), 10) || 20);
  let data;
  if (opt('--runs-json', null)) {
    data = JSON.parse(readFileSync(opt('--runs-json'), 'utf8'));
    data.event = event;
  } else {
    const repo = opt('--repo', null) || detectRepo();
    data = fetchRuns({ repo, event, limit });
  }
  const s = summarize(data, limit);
  if (argv.includes('--json')) {
    console.log(JSON.stringify(s, null, 2));
  } else {
    console.log(`event: ${s.event}`);
    console.log(`runs considered: ${s.runs} (successful used for p50: ${s.successful_runs})`);
    console.log(`wall-clock p50: ${s.wall_clock_p50_human ?? 'n/a'} (${s.wall_clock_p50_sec ?? 'n/a'}s)`);
    console.log(`job-minutes p50: ${s.job_minutes_p50 ?? 'n/a'}`);
    console.log(`failure rate: ${s.failure_rate_pct}%`);
    console.log(`failed jobs: ${JSON.stringify(s.failed_jobs)}`);
  }
}
