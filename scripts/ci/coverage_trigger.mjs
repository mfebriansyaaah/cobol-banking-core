// Coverage trigger classifier (CI-004).
//
// Decides whether a change set requires the curated COBOL coverage
// measurement (`scripts/ci/coverage.sh --cobol-only`). Extracted from the
// shell `case` block so the scope is unit-tested instead of copy-pasted.
//
// Groups:
//   cobol       curated modules, shared COBOL inputs, build, C bridge
//   data        database surface, exercised suites/cases
//   measurement the measurement scripts and baselines themselves
//   gateway     the gateway suites that exercise COBOL actions through the
//               instrumented binary (a route change can drop COBOL coverage)
// Known-safe paths (docs, generated data, build noise) never trigger.
// Anything else is `unknown` and triggers: a false full measurement wastes
// minutes, a false skip silently drops coverage.
//
// Usage:
//   node scripts/ci/coverage_trigger.mjs [--stdin] [files...]
// Exit 0 when the measurement is required, 1 when it can be skipped.
// Prints the first triggering `<group>:<file>` on stdout when triggered.
//
// Pure functions (classifyFile, shouldMeasure) are imported by
// scripts/test/coverage_trigger.test.mjs.
const TRIGGER_RULES = [
  [
    'cobol',
    [
      /^cobol\/src\/[^/]*_core\.cob$/,
      /^cobol\/copy\//,
      /^cobol\/c_lib\//,
      /^cobol\/src\/[^/]*\.[ch]$/,
      /^build\.sh$/,
      /^cobol\/Makefile$/,
    ],
  ],
  ['data', [/^database\//, /^tests\/cobol\/cases\//, /^tests\/cobol\/table_runner\.sh$/, /^tests\/db\//]],
  [
    'measurement',
    [
      /^scripts\/ci\/coverage\.sh$/,
      /^scripts\/ci\/coverage_trigger\.mjs$/,
      /^scripts\/coverage\//,
      /^tests\/coverage_/,
    ],
  ],
  ['gateway', [/^middleware\/src\//, /^middleware\/test\//, /^tests\/gateway\//, /^tests\/lib\//]],
];

// Generated or volatile paths that can never affect measured COBOL lines.
const SAFE_RULES = [
  /^docs\//,
  /^(README\.md|CONTRIBUTING\.md|SECURITY\.md|CHANGELOG\.md|LICENSE)$/,
  /^manifest\/modules\.json$/,
  /^(coverage\/|artifacts\/|backups\/|test-results\/|reports\/|tmp\/)/,
  /^(input\.txt|output\.txt|sql_debug\.log|\.DS_Store|Thumbs\.db)$/,
  /^tests\/\.dbenv$/,
];

/**
 * Classify one repo-relative path. Returns a trigger group ('cobol',
 * 'data', 'measurement', 'gateway'), 'unknown' for unrecognized paths
 * (safe default: measure), or null for known-safe paths (skip).
 */
export function classifyFile(file) {
  const f = String(file);
  if (!f) return null;
  for (const [group, patterns] of TRIGGER_RULES) {
    if (patterns.some((re) => re.test(f))) return group;
  }
  if (SAFE_RULES.some((re) => re.test(f))) return null;
  return 'unknown';
}

/** True when at least one path requires the curated measurement. */
export function shouldMeasure(files) {
  return (files || []).some((f) => classifyFile(f) !== null);
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
    const hit = files.find((f) => classifyFile(f) !== null);
    if (hit === undefined) {
      process.exit(1);
    }
    console.log(`trigger:${classifyFile(hit)}:${hit}`);
    process.exit(0);
  };
  run();
}
