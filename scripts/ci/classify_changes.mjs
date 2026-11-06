// Changed-file classifier for docs-only fast path (CI-011).
//
// `docs_only` is true only when every changed path is documentation:
// docs/, root doc files, issue/PR templates, CODEOWNERS. Anything else —
// code, tests, workflows, database, manifest, build files, package
// manifests, or any unrecognized path — means a full run (fail safe).
// An empty change set is also full: nothing recognized, nothing skipped.
//
// Usage:
//   printf '%s\n' <files> | node scripts/ci/classify_changes.mjs --stdin
// Always exits 0 and prints `docs_only=true|false` (the CI step defaults
// to full on any error, so the gate can never fail closed into a skip).
// With explicit file args instead of --stdin: same contract.
//
// Pure functions (classifyFile, isDocsOnly) are imported by
// scripts/test/classify_changes.test.mjs.
const DOCS_PREFIXES = ['docs/', '.github/ISSUE_TEMPLATE/'];
const DOCS_FILES = new Set([
  'README.md',
  'CONTRIBUTING.md',
  'SECURITY.md',
  'CHANGELOG.md',
  'LICENSE',
  '.github/pull_request_template.md',
  '.github/CODEOWNERS',
]);

const FULL_PATTERNS = [
  /^\.github\/workflows\//,
  /^scripts\//,
  /^tests\//,
  /^middleware\//,
  /^cobol\//,
  /^database\//,
  /^manifest\//,
  /^(build\.sh|Makefile|package[^/]*\.json)$/,
];

/**
 * Classify one repo-relative path: 'docs', 'full', or 'unknown'
 * (unknown fails safe to full).
 */
export function classifyFile(file) {
  const f = String(file);
  if (!f) return 'unknown';
  if (DOCS_FILES.has(f) || DOCS_PREFIXES.some((p) => f.startsWith(p))) return 'docs';
  if (FULL_PATTERNS.some((re) => re.test(f))) return 'full';
  return 'unknown';
}

/** True only for a non-empty, all-docs change set. */
export function isDocsOnly(files) {
  const list = (files || []).map((f) => String(f).trim()).filter(Boolean);
  return list.length > 0 && list.every((f) => classifyFile(f) === 'docs');
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
      console.log('usage: classify_changes.mjs [--stdin] [files...]');
      process.exit(0);
    }
    if (args.includes('--stdin')) {
      const raw = await readStdin();
      files = [...files, ...raw.split('\n')];
    }
    console.log(`docs_only=${isDocsOnly(files)}`);
    process.exit(0);
  };
  run();
}
