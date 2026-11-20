// Impact audit (PR-01, shadow only).
//
// Compares the advisory impact plan against actual CI results: every job the
// plan would have skipped is checked for failure. A failure on a would-skip
// job is a false negative (the mapping is unsafe); anything else is safe.
// Advisory only: always exits 0 on a well-formed audit (exit 2 on usage or
// unreadable inputs) so it never gates the pipeline.
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const VALUE_FLAGS = new Set(['--plan', '--jobs-json', '--out']);

function usage() {
  console.log("usage: impact-audit.mjs --plan <impact-plan.json> --jobs-json '<toJSON(needs)>' [--out <audit.json>]");
}

function splitFlag(arg) {
  const eq = arg.indexOf('=');
  if (eq < 0) return { name: arg, inline: null };
  return { name: arg.slice(0, eq), inline: arg.slice(eq + 1) };
}

function parseArgs(argv) {
  const out = { plan: null, jobsJson: null, out: null };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--help' || a === '-h') {
      usage();
      process.exit(0);
    }
    const { name, inline } = splitFlag(a);
    if (!VALUE_FLAGS.has(name)) {
      console.error(`unknown argument: ${a}`);
      process.exit(2);
    }
    const attr = name === '--plan' ? 'plan' : name === '--jobs-json' ? 'jobsJson' : 'out';
    if (inline !== null) {
      out[attr] = inline || null;
    } else {
      out[attr] = argv[i + 1] ?? null;
      i += 1;
    }
  }
  return out;
}

function readJsonInput(raw, label) {
  try {
    return JSON.parse(raw);
  } catch (e) {
    console.error(`FAIL: cannot parse ${label}: ${e.message}`);
    process.exit(2);
  }
  return null;
}

function readPlan(planPath) {
  let raw;
  try {
    raw = readFileSync(planPath, 'utf8');
  } catch (e) {
    console.error(`FAIL: cannot read plan ${planPath}: ${e.message}`);
    process.exit(2);
  }
  return readJsonInput(raw, `plan ${planPath}`);
}

function buildAudit(plan, jobs) {
  const wouldSkip = Array.isArray(plan.would_skip) ? plan.would_skip : [];
  const results = {};
  for (const [id, spec] of Object.entries(jobs || {})) {
    results[id] = spec && typeof spec.result === 'string' ? spec.result : 'unknown';
  }
  const falseNegatives = wouldSkip.filter((id) => results[id] === 'failure');
  return {
    version: 1,
    plan_mode: plan.mode ?? null,
    would_skip: [...wouldSkip].sort(),
    results,
    false_negatives: [...falseNegatives].sort(),
    unmapped: Array.isArray(plan.unmapped) ? plan.unmapped : [],
    ok: falseNegatives.length === 0,
  };
}

function renderReport(audit) {
  return [
    '## Impact audit (advisory)',
    '',
    `- Plan mode: ${audit.plan_mode ?? 'n/a'}`,
    `- Would skip: ${audit.would_skip.length ? audit.would_skip.join(', ') : 'none'}`,
    `- False negatives: ${audit.false_negatives.length ? audit.false_negatives.join(', ') : 'none'}`,
    `- Unmapped: ${audit.unmapped.length ? audit.unmapped.join(', ') : 'none'}`,
    '',
  ].join('\n');
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.plan || !args.jobsJson) {
    usage();
    process.exit(2);
  }
  const plan = readPlan(args.plan);
  const jobs = readJsonInput(args.jobsJson, '--jobs-json');
  const audit = buildAudit(plan, jobs);
  const outPath = args.out || 'artifacts/impact-audit/impact-audit.json';
  mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
  writeFileSync(outPath, `${JSON.stringify(audit, null, 2)}\n`, 'utf8');
  const text = `${renderReport(audit)}\n`;
  process.stdout.write(text);
  const summary = process.env.GITHUB_STEP_SUMMARY;
  if (summary) {
    try {
      appendFileSync(summary, text, 'utf8');
    } catch {
      // best effort; the artifact still holds the audit.
    }
  }
}

if (import.meta.url === `file://${process.argv[1]}`) main();
