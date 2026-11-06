// Quarantine flag helper: prints a node --test skip flag for flaky tests.
//
// Reads middleware/test/quarantine.txt (relative to the repo root, resolved
// from this file so it works regardless of cwd). Each non-comment line:
//   <test-name pattern> | <reason> | <ticket> | <expiry YYYY-MM-DD>
// Expired entries are excluded (fail-safe: run the full suite) — the unit
// test fails on expired entries so the owner must renew or remove them.
//
// Behavior:
//   QUARANTINE=1  -> prints "--test-skip-pattern='p1|p2'" (or '' if none)
//   otherwise     -> prints '' (local/dev and nightly run everything)
// Always exits 0 and never prints secrets; on read/parse error it prints ''
// so the gate can never fail closed into a skip.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
export const QUARANTINE_FILE = join(ROOT, 'middleware', 'test', 'quarantine.txt');

export function parseQuarantine(text) {
  const entries = [];
  for (const [idx, raw] of String(text).split('\n').entries()) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const parts = line.split('|').map((s) => s.trim());
    if (parts.length !== 4 || !parts[0] || !parts[1] || !parts[2]) {
      throw new Error(
        `quarantine.txt line ${idx + 1}: expected ` +
          `"<pattern> | <reason> | <ticket> | <YYYY-MM-DD>", got ${JSON.stringify(raw)}`,
      );
    }
    const [, , , expires] = parts;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(expires)) {
      throw new Error(`quarantine.txt line ${idx + 1}: bad expiry ${JSON.stringify(expires)} (want YYYY-MM-DD)`);
    }
    entries.push({ pattern: parts[0], reason: parts[1], ticket: parts[2], expires });
  }
  return entries;
}

export function loadEntries(file = QUARANTINE_FILE) {
  return parseQuarantine(readFileSync(file, 'utf8'));
}

/** Patterns still quarantined on `today` (YYYY-MM-DD, inclusive boundary). */
export function activePatterns(entries, today) {
  return entries.filter((e) => e.expires >= today).map((e) => e.pattern);
}

/**
 * Shell-safe flag: emitted through $(...) inside npm scripts, where the
 * shell will NOT re-process quotes — so the value must contain no quotes
 * and no whitespace. Literal spaces in patterns become \s+ (regex).
 */
export function formatFlag(patterns) {
  if (!patterns.length) return '';
  const safe = patterns.map((p) => p.replace(/ /g, '\\s+'));
  return `--test-skip-pattern=(${safe.join('|')})`;
}

function todayUTC() {
  return new Date().toISOString().slice(0, 10);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    if (process.env.QUARANTINE !== '1') {
      process.stdout.write('');
    } else {
      const entries = loadEntries();
      process.stdout.write(formatFlag(activePatterns(entries, todayUTC())));
    }
  } catch {
    process.stdout.write('');
  }
}
