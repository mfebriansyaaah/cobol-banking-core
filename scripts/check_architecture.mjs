// Architecture fitness functions (arch9 WP-01).
//
// Invariants that must hold without relying on reviewer discipline.
// Every rule below maps to an ADR-0015..0019 invariant; each violation is a
// fail-closed gate, and every exception lives in a tests/ allowlist with an
// owner and an expiry date (expired or stale entries fail the gate).
//
// Rules:
//   A1  No direct CALL "SQL_BEGIN" in cobol/src/*_core.cob or cobol/copy/*.cpy
//       (except cobol/copy/common_txn.cpy, the TXN-BEGIN kernel). Migrated by
//       WP-10; allowlist: tests/architecture_sql_begin_allowlist.txt.
//   A2  No bare CALL "SQL_COMMIT" in cobol/src/*.cob (use PERFORM
//       COMMIT-CHECKED). Mirrors scripts/check_commit_results.mjs; no allowlist.
//   A3  No audit_trail status 'DENIED' (enum is SUCCESS/FAILED).
//       Exceptions: tests/architecture_exceptions.txt.
//   A4  No gl_journal lookup by description (link by txn_ref id instead).
//       Exceptions: tests/architecture_exceptions.txt.
//   A5  middleware/src/** must not import middleware/services/** directly
//       (go through middleware/adapters/**). Exceptions:
//       tests/architecture_exceptions.txt (server.js until WP-21).
//   A6  COBOL modules must stay <= 1000 lines (split in WP-24).
//       Allowlist: tests/architecture_module_size_allowlist.txt.
//   A7  Duplicate route actions must be allowlisted legacy aliases in
//       tests/legacy_routes.txt, or carry deprecated:true on the route.
//       (Canonical shared actions PING/IDV_REVIEW_* are documented there.)
//
// Allowlist format (all files): `key|owner|expiry|reason` (`#` = comment).
// expiry is YYYY-MM-DD; a past expiry fails. An entry with no matching live
// violation is stale and fails (ratchet both directions).
//
// Usage: node scripts/check_architecture.mjs [root]
// Exit: 0 ok, 1 violation, 2 usage error.
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let ROOT = '.';
for (const a of args) {
  if (a === '--help' || a === '-h') {
    console.log('usage: check_architecture.mjs [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    ROOT = a;
  }
}
ROOT = path.resolve(ROOT);

const errors = [];
const rel = (p) => path.relative(ROOT, p).split(path.sep).join('/');
const today = () => new Date().toISOString().slice(0, 10);

// --- Allowlist loading -----------------------------------------------------

// Parse one allowlist line into { key, owner, expiry } or an error string.
function parseAllowlistLine(line, positions, need, layout) {
  const parts = line.split('|').map((s) => s.trim());
  const entry = {
    key: parts[positions.key],
    owner: parts[positions.owner],
    expiry: parts[positions.expiry],
  };
  if (parts.length < need || !entry.key || !entry.owner || !entry.expiry) {
    return `malformed entry (want ${layout}): ${line}`;
  }
  // '-' expiry = intentional permanent entry (no sunset, e.g. shared actions).
  if (entry.expiry !== '-' && !/^\d{4}-\d{2}-\d{2}$/.test(entry.expiry)) {
    return `bad expiry (want YYYY-MM-DD or -): ${line}`;
  }
  return entry;
}

function loadAllowlist(file, rule, layout = 'key|owner|expiry|reason') {
  const p = path.join(ROOT, 'tests', file);
  if (!existsSync(p)) return new Map();
  const positions = Object.fromEntries(layout.split('|').map((name, i) => [name, i]));
  const need = Math.max(positions.key, positions.owner, positions.expiry) + 1;
  const out = new Map();
  for (const [i, raw] of readFileSync(p, 'utf8').split('\n').entries()) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const entry = parseAllowlistLine(line, positions, need, layout);
    if (typeof entry === 'string') {
      errors.push(`${file}:${i + 1} ${entry}`);
      continue;
    }
    if (out.has(entry.key)) {
      errors.push(`${file}:${i + 1} duplicate key: ${entry.key}`);
      continue;
    }
    out.set(entry.key, { owner: entry.owner, expiry: entry.expiry, file, line: i + 1 });
  }
  // Expired entries fail even when they still match: renew or remove.
  // '-' expiry never expires (intentional permanent entries only).
  for (const [key, e] of out) {
    if (e.expiry !== '-' && e.expiry < today()) {
      errors.push(`${rule} exception expired on ${e.expiry} (renew or remove): ${key} [${e.file}:${e.line}]`);
    }
  }
  return out;
}

function checkAllowlisted(rule, allow, key, where, seen) {
  const e = allow.get(key);
  if (!e) {
    errors.push(`${rule} ${where}: ${key}`);
    return;
  }
  if (e.expiry !== '-' && e.expiry < today()) return; // already reported as expired
  seen.add(key);
}

function reportStale(rule, allow, seen) {
  for (const [key, e] of allow) {
    if (!seen.has(key) && (e.expiry === '-' || e.expiry >= today())) {
      errors.push(`${rule} stale exception (violation gone; remove the line): ${key} [${e.file}:${e.line}]`);
    }
  }
}

// --- File helpers ----------------------------------------------------------

function walk(dir, ext) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const name of readdirSync(dir).sort()) {
    const p = path.join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p, ext));
    else if (name.endsWith(ext)) out.push(p);
  }
  return out;
}

// --- A1: direct SQL_BEGIN ---------------------------------------------------

const A1_ALLOW = loadAllowlist('architecture_sql_begin_allowlist.txt', 'A1');
{
  const seen = new Set();
  const files = [
    ...walk(path.join(ROOT, 'cobol', 'src'), '.cob'),
    ...walk(path.join(ROOT, 'cobol', 'copy'), '.cpy'),
  ];
  for (const f of files) {
    const r = rel(f);
    if (r === 'cobol/copy/common_txn.cpy') continue;
    if (!readFileSync(f, 'utf8').includes('CALL "SQL_BEGIN"')) continue;
    checkAllowlisted('A1', A1_ALLOW, r, 'direct CALL "SQL_BEGIN" (use PERFORM TXN-BEGIN)', seen);
  }
  reportStale('A1', A1_ALLOW, seen);
}

// --- A2: bare SQL_COMMIT in src ---------------------------------------------

{
  for (const f of walk(path.join(ROOT, 'cobol', 'src'), '.cob')) {
    const src = readFileSync(f, 'utf8');
    const n = (src.match(/CALL\s+"SQL_COMMIT"/g) || []).length;
    if (n > 0) {
      errors.push(`A2 ${rel(f)}: ${n} bare CALL "SQL_COMMIT" (use PERFORM COMMIT-CHECKED)`);
    }
  }
}

// --- A3/A4: forbidden literals (exception-keyed) -----------------------------

const EXC = loadAllowlist('architecture_exceptions.txt', 'AX');
for (const [key, e] of EXC) {
  if (!/^(A3|A4|A5):.+/.test(key)) {
    errors.push(`AX unknown rule prefix (want A3:|A4:|A5:): ${key} [${e.file}:${e.line}]`);
  }
}
{
  const seen = new Set();
  const files = [
    ...walk(path.join(ROOT, 'cobol', 'src'), '.cob'),
    ...walk(path.join(ROOT, 'cobol', 'copy'), '.cpy'),
  ];
  for (const f of files) {
    const r = rel(f);
    const src = readFileSync(f, 'utf8');
    if (src.includes("'DENIED'")) {
      checkAllowlisted('A3', EXC, `A3:${r}`, "audit status 'DENIED' (enum is SUCCESS/FAILED)", seen);
    }
    if (src.includes('SELECT id FROM gl_journal WHERE description')) {
      checkAllowlisted('A4', EXC, `A4:${r}`, 'gl_journal lookup by description (link by txn_ref)', seen);
    }
  }
  // A5: middleware/src must not import services directly.
  for (const f of walk(path.join(ROOT, 'middleware', 'src'), '.js')) {
    const r = rel(f);
    const src = readFileSync(f, 'utf8');
    if (/(^|\W)from\s+['"]\.\.(\/\.\.)*\/services\//.test(src)) {
      checkAllowlisted('A5', EXC, `A5:${r}`, 'direct services import (go through adapters)', seen);
    }
  }
  const usedRules = new Set(['A3', 'A4', 'A5']);
  for (const [key, e] of EXC) {
    const rule = key.split(':')[0];
    if (!usedRules.has(rule)) continue;
    if (!seen.has(key) && (e.expiry === '-' || e.expiry >= today())) {
      errors.push(`AX stale exception (violation gone; remove the line): ${key} [${e.file}:${e.line}]`);
    }
  }
}

// --- A6: module size ----------------------------------------------------------

const A6_ALLOW = loadAllowlist('architecture_module_size_allowlist.txt', 'A6');
const A6_MAX = 1000;
{
  const seen = new Set();
  for (const f of walk(path.join(ROOT, 'cobol', 'src'), '.cob')) {
    const lines = readFileSync(f, 'utf8').split('\n').length;
    if (lines <= A6_MAX) continue;
    checkAllowlisted('A6', A6_ALLOW, rel(f), `module has ${lines} lines (max ${A6_MAX}; split in WP-24)`, seen);
  }
  reportStale('A6', A6_ALLOW, seen);
}

// --- A7: duplicate route actions -----------------------------------------------

const A7_ALLOW = loadAllowlist('legacy_routes.txt', 'A7', 'key|expiry|owner|reason');
{
  // Balanced-brace route parser (mirrors scripts/check_route_auth.mjs):
  // finds { method:, path:, action: } objects, ignoring braces in strings.
  const routesDir = path.join(ROOT, 'middleware', 'src', 'routes');
  const found = [];
  if (existsSync(routesDir)) {
    for (const name of readdirSync(routesDir).filter((f) => f.endsWith('.js') && f !== 'index.js').sort()) {
      const source = readFileSync(path.join(routesDir, name), 'utf8');
      for (let i = 0; i < source.length; i += 1) {
        if (source[i] !== '{') continue;
        if (!/^\s*method\s*:/.test(source.slice(i + 1, i + 40))) continue;
        let depth = 0;
        let quote = null;
        let j = i;
        for (; j < source.length; j += 1) {
          const ch = source[j];
          if (quote) {
            if (ch === quote && source[j - 1] !== '\\') quote = null;
            continue;
          }
          if (ch === "'" || ch === '"') {
            quote = ch;
            continue;
          }
          if (ch === '{') depth += 1;
          else if (ch === '}') {
            depth -= 1;
            if (depth === 0) break;
          }
        }
        const body = source.slice(i, j + 1);
        const action = body.match(/action\s*:\s*'([A-Z0-9_]+)'/);
        if (action) {
          found.push({ action: action[1], deprecated: /deprecated\s*:\s*true/.test(body) });
        }
        i = j;
      }
    }
  }
  const byAction = new Map();
  for (const r of found) {
    if (!byAction.has(r.action)) byAction.set(r.action, []);
    byAction.get(r.action).push(r);
  }
  const seen = new Set();
  for (const [action, uses] of [...byAction.entries()].sort()) {
    if (uses.length < 2) continue;
    if (uses.every((u) => u.deprecated)) continue;
    checkAllowlisted('A7', A7_ALLOW, action, `action on ${uses.length} routes (mark legacy deprecated:true or allowlist)`, seen);
  }
  reportStale('A7', A7_ALLOW, seen);
}

// --- Verdict -------------------------------------------------------------------

if (errors.length) {
  console.error('ARCHITECTURE VIOLATIONS:');
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}
console.log('OK: architecture rules pass (A1 SQL_BEGIN, A2 SQL_COMMIT, A3/A4/A5 exceptions, A6 size, A7 legacy routes)');
