// Recommended-module coverage ratchet (Phase 2).
//
// `manifest/module_quality.json` marks 31 modules as recommended for training.
// The curated COBOL coverage set measures 14 of them; the other 17 need a DB
// suite entry and a measured number. Until that measurement lands they are
// recorded explicitly in tests/coverage_recommended_backlog.txt, so a new
// recommended module cannot appear unmeasured without a reviewed entry.
//
// Usage: node scripts/check_coverage_recommended.mjs [root]
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const BACKLOG = 'tests/coverage_recommended_backlog.txt';

function readList(file) {
  const out = new Set();
  if (!existsSync(file)) return out;
  for (const line of readFileSync(file, 'utf8').split('\n')) {
    const text = line.trim();
    if (!text || text.startsWith('#')) continue;
    out.add(text.split(/\s+/)[0]);
  }
  return out;
}

export function check(rootDir) {
  const quality = JSON.parse(readFileSync(path.join(rootDir, 'manifest', 'module_quality.json'), 'utf8')).modules;
  const recommended = quality.filter((m) => m.recommendedForTraining);
  const measured = new Set(recommended.filter((m) => m.coverageStatus !== 'unmeasured').map((m) => m.module));
  const backlog = readList(path.join(rootDir, BACKLOG));
  const errors = [];

  for (const m of recommended) {
    if (measured.has(m.module) && backlog.has(m.module)) {
      errors.push(`${m.module}: measured but still in the coverage backlog`);
    } else if (!measured.has(m.module) && !backlog.has(m.module)) {
      errors.push(`${m.module}: recommended module is unmeasured and not in ${BACKLOG}`);
    }
  }
  for (const module of backlog) {
    const entry = quality.find((m) => m.module === module);
    if (!entry) errors.push(`${module}: backlog entry has no module_quality row`);
    else if (!entry.recommendedForTraining) errors.push(`${module}: backlog entry is not recommended for training`);
    else if (entry.coverageStatus !== 'unmeasured') errors.push(`${module}: measured module is stale in the backlog`);
  }
  return { recommended: recommended.length, measured: measured.size, backlog: backlog.size, errors };
}

function main(argv) {
  const rootDir = path.resolve(argv[0] || path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..'));
  const { recommended, measured, backlog, errors } = check(rootDir);
  if (errors.length > 0) {
    for (const err of errors) console.error(`FAIL: ${err}`);
    return 1;
  }
  console.log(`OK: ${recommended} recommended module(s): ${measured} measured, ${backlog} explicitly backlogged`);
  return 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
