// JavaScript complexity ratchet (Phase 2).
//
// ESLint's config-level ratchet is 20. This gate enforces the next step (15)
// without forcing a risky big-bang refactor: every function currently above
// 15 must be recorded in tests/js_complexity_baseline.txt with its current
// maximum. New hotspots fail, and a function that grows past its recorded
// maximum fails too. `--write` refreshes the baseline after a reviewed split.
//
// Usage:
//   node scripts/check_js_complexity.mjs [root]
//   node scripts/check_js_complexity.mjs --write [root]
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ESLint } from 'eslint';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const BASELINE = 'tests/js_complexity_baseline.txt';
export const THRESHOLD = 15;
const TARGETS = ['middleware/**/*.js', 'scripts/**/*.mjs'];

function parseFunctionLabel(message) {
  const named = message.match(/(?:Async )?(?:function|arrow function) '([^']+)'/);
  if (named) return named[1];
  return null;
}

export function entryKey(file, line, message) {
  const name = parseFunctionLabel(message);
  return `${file}|${name ?? `@${line}`}`;
}

export async function collect(rootDir = ROOT) {
  const eslint = new ESLint({
    cwd: rootDir,
    overrideConfig: {
      files: ['middleware/**/*.js', 'scripts/**/*.mjs'],
      rules: { complexity: ['warn', THRESHOLD] },
    },
  });
  const results = await eslint.lintFiles(TARGETS);
  const rows = [];
  for (const result of results) {
    const file = path.relative(rootDir, result.filePath).split(path.sep).join('/');
    for (const msg of result.messages) {
      if (msg.ruleId !== 'complexity') continue;
      const n = Number((msg.message.match(/complexity of (\d+)/) || [])[1] || 0);
      if (n <= THRESHOLD) continue;
      rows.push({ file, line: msg.line, key: entryKey(file, msg.line, msg.message), complexity: n });
    }
  }
  return rows.sort((a, b) => a.file.localeCompare(b.file) || a.key.localeCompare(b.key));
}

export function readBaseline(rootDir = ROOT) {
  const p = path.join(rootDir, BASELINE);
  const out = new Map();
  if (!existsSync(p)) return out;
  for (const line of readFileSync(p, 'utf8').split('\n')) {
    const text = line.trim();
    if (!text || text.startsWith('#')) continue;
    const parts = text.split('|');
    if (parts.length !== 3) continue;
    out.set(`${parts[0]}|${parts[1]}`, Number(parts[2]));
  }
  return out;
}

export function renderBaseline(rows) {
  return [
    '# JavaScript complexity ratchet (ESLint complexity > 15).',
    '# Format: file|function-or-anonymous-line|max complexity.',
    '# `scripts/check_js_complexity.mjs --write` refreshes after a reviewed split.',
    ...rows.map((r) => `${r.file}|${r.key.split('|')[1]}|${r.complexity}`),
    '',
  ].join('\n');
}

export async function check(rootDir = ROOT) {
  const rows = await collect(rootDir);
  const baseline = readBaseline(rootDir);
  const errors = [];
  const seen = new Set();
  for (const row of rows) {
    const key = `${row.file}|${row.key.split('|')[1]}`;
    seen.add(key);
    const max = baseline.get(key);
    if (max === undefined) {
      errors.push(`new hotspot >${THRESHOLD}: ${row.file} ${row.key.split('|')[1]} (${row.complexity})`);
    } else if (row.complexity > max) {
      errors.push(`complexity increased: ${row.file} ${row.key.split('|')[1]} ${max} -> ${row.complexity}`);
    }
  }
  for (const key of baseline.keys()) {
    if (!seen.has(key)) errors.push(`stale baseline entry (function removed/renamed): ${key}`);
  }
  return { rows, errors };
}

async function main(argv) {
  const write = argv.includes('--write');
  const rootArg = argv.find((a) => a !== '--write');
  const rootDir = path.resolve(rootArg || ROOT);
  const rows = await collect(rootDir);
  if (write) {
    writeFileSync(path.join(rootDir, BASELINE), renderBaseline(rows));
    console.log(`wrote ${BASELINE} (${rows.length} functions > ${THRESHOLD})`);
    return 0;
  }
  const { errors } = await check(rootDir);
  if (errors.length > 0) {
    for (const err of errors) console.error(`FAIL: ${err}`);
    return 1;
  }
  console.log(`OK: ${rows.length} function(s) above ${THRESHOLD} are baselined; no new hotspots`);
  return 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await main(process.argv.slice(2));
}
