import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { parseQuarantine, activePatterns, formatFlag, loadEntries } from '../ci/quarantine_flag.mjs';

const ENTRY = (pattern, expires) => `${pattern} | auth-500 flake | DOMAIN-REVIEW | ${expires}`;

describe('parseQuarantine', () => {
  it('parses active entries, skips blanks and comments', () => {
    const entries = parseQuarantine(`# comment\n\n${ENTRY('refresh rotates', '2026-12-15')}\n`);
    assert.equal(entries.length, 1);
    assert.equal(entries[0].pattern, 'refresh rotates');
    assert.equal(entries[0].expires, '2026-12-15');
  });

  it('rejects malformed lines (negative control)', () => {
    assert.throws(() => parseQuarantine('just a pattern\n'), /quarantine\.txt/);
    assert.throws(() => parseQuarantine('a | b | c | not-a-date\n'), /expiry/);
  });
});

describe('activePatterns', () => {
  it('excludes expired entries relative to today', () => {
    const entries = parseQuarantine(`${ENTRY('old flake', '2026-01-01')}\n${ENTRY('new flake', '2026-12-15')}\n`);
    assert.deepEqual(activePatterns(entries, '2026-11-06'), ['new flake']);
  });

  it('keeps entries expiring today (inclusive boundary)', () => {
    const entries = parseQuarantine(`${ENTRY('edge', '2026-11-06')}\n`);
    assert.deepEqual(activePatterns(entries, '2026-11-06'), ['edge']);
  });
});

describe('formatFlag', () => {
  it('emits an empty string when nothing is quarantined', () => {
    assert.equal(formatFlag([]), '');
  });

  it('emits a shell-safe --test-skip-pattern alternation (no quotes/spaces)', () => {
    const flag = formatFlag(['a', 'b c']);
    assert.match(flag, /^--test-skip-pattern=/);
    assert.ok(!flag.includes("'") && !flag.includes('"') && !flag.includes(' '));
    assert.match(flag, /\(a\|b\\s\+c\)/);
  });
});

describe('real quarantine.txt (expiry enforcement)', () => {
  it('has no expired entries (forces owner renewal)', () => {
    const today = new Date().toISOString().slice(0, 10);
    const entries = loadEntries();
    const expired = entries.filter((e) => e.expires < today);
    assert.deepEqual(
      expired.map((e) => e.pattern),
      [],
      `expired quarantine entries: renew or remove them`,
    );
  });

  it('CLI prints empty flag when QUARANTINE is unset', () => {
    const out = execFileSync(process.execPath, ['scripts/ci/quarantine_flag.mjs'], {
      encoding: 'utf8',
      env: { ...process.env, QUARANTINE: '0' },
    });
    assert.equal(out.trim(), '');
  });
});
