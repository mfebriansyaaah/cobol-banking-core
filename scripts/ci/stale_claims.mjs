// Stale-claim patterns for the docs gate (CI-006).
//
// Volatile fleet numbers live in generated stats or behind commands, not
// hardcoded in prose. Every entry here fails `node scripts/check_docs.mjs`
// until the prose is fixed or the line is explicitly marked historical.
// Lines containing "historical" (any case) are skipped: the R0 evidence
// record keeps its original numbers on purpose.
//
// Pure functions (STALE_RULES, findStaleClaims) are imported by
// scripts/test/stale_claims.test.mjs.
export const STALE_RULES = [
  {
    id: 'stale-count-db-suites',
    pattern: /274 DB suites/,
    message: 'DB suite count is stale (run: ls tests/db/*_db_tests.sh | wc -l)',
  },
  {
    id: 'stale-count-files',
    pattern: /273 files/,
    message: 'DB suite file count is stale (run: ls tests/db/*_db_tests.sh | wc -l)',
  },
  {
    id: 'stale-count-actions',
    pattern: /2,780 route|2780 route/,
    message: 'route action count is stale (see README generated stats)',
  },
  {
    id: 'stale-count-shards',
    pattern: /~537 suites/,
    message: 'shard suite count is stale (run: ls tests/db/*_db_tests.sh | wc -l)',
  },
  {
    id: 'stale-count-curated',
    pattern: /24 curated/,
    message: 'curated module count is stale (see the list in scripts/ci/coverage.sh)',
  },
  {
    id: 'required-check-name',
    pattern: /required[^.\n]*db-aggregate|db-aggregate[^.\n]*required/i,
    message: 'required check must use the display name `db aggregate` (space), not the job ID',
  },
  {
    id: 'retired-readme-claim',
    pattern: /No hosted CI/,
    message: 'README still contains a retired claim',
  },
  {
    id: 'retired-roadmap-claim',
    pattern: /All 11 roadmap items complete/,
    message: 'README still contains a retired claim',
  },
];

/**
 * Scan files for stale claims. Input: [{ path, text }].
 * Returns [{ path, line, rule, message }], one row per offending line.
 */
export function findStaleClaims(files) {
  const hits = [];
  for (const { path, text } of files || []) {
    const lines = String(text).split('\n');
    lines.forEach((content, idx) => {
      if (/historical/i.test(content)) return;
      for (const rule of STALE_RULES) {
        if (rule.pattern.test(content)) {
          hits.push({ path, line: idx + 1, rule: rule.id, message: rule.message });
          break;
        }
      }
    });
  }
  return hits;
}
