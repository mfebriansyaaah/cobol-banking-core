// Test support: seed a VERIFIED user with the shared test password so the
// gateway suites can exercise admin-only and self-or-admin paths. Seed helpers
// return false when the mysql client is unavailable; callers must pass the
// result through requireSeed so a broken database fails the test instead of
// silently skipping it (a skip would hide lost coverage as green).
import { execFileSync } from 'node:child_process';
import { createHmac } from 'node:crypto';

function dbConfig() {
  return {
    user: process.env.DB_USER ?? 'cobol_user',
    pass: process.env.DB_PASS ?? 'cobol_pass',
    name: process.env.DB_NAME ?? 'cobol_db',
    host: process.env.DB_HOST ?? '',
    port: process.env.DB_PORT ?? '',
  };
}

// Build mysql client arguments. DB_HOST/DB_PORT matter in CI, where the
// database is a service container reachable over TCP and there is no local
// socket; without host/port the client silently connects to the wrong place.
function mysqlArgs(sql, extra = []) {
  const { user, pass, name, host, port } = dbConfig();
  const args = extra.slice();
  if (host) args.push('-h', host);
  if (port) args.push('-P', port);
  args.push('-u', user, `-p${pass}`, name, '-e', sql);
  return args;
}

// Fail the test when a database prerequisite cannot be seeded. Every gateway
// test needs the database; skipping would report green while covering nothing.
export function requireSeed(ok, what) {
  if (!ok) throw new Error(`test prerequisite failed: cannot ${what} (mysql required)`);
}

export function seedUser(email, role = 'USER') {
  const sql =
    'INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES ' +
    `('${email}',CONCAT('SHA256_',SHA2('secret123',256)),'Test User','1990-01-01','VERIFIED','${role}') ` +
    `ON DUPLICATE KEY UPDATE role='${role}', status='VERIFIED', password_hash=VALUES(password_hash);`;
  try {
    execFileSync('mysql', mysqlArgs(sql), { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

// Enable MFA for a seeded user with a known base32 secret (so tests can produce
// valid TOTP codes). Returns false when mysql is unavailable.
export const TEST_MFA_SECRET = 'JBSWY3DPEHPK3PXP';
export function enableMfa(email, secret = TEST_MFA_SECRET) {
  return runSql(`UPDATE users SET mfa_enabled=1, mfa_secret='${secret}' WHERE email='${email}'`);
}

// TOTP code for a base32 secret (RFC 6238, SHA-1, 6 digits, 30s). Near the
// end of a window the NEXT step is minted, so a code computed in step N is
// still accepted in step N+1 under load (the server allows +/-1 step).
export function totp(secret) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const ch of secret.toUpperCase().replace(/=+$/, '')) {
    const idx = alphabet.indexOf(ch);
    if (idx < 0) continue;
    bits += idx.toString(2).padStart(5, '0');
  }
  const bytes = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) bytes.push(parseInt(bits.slice(i, i + 8), 2));
  const now = Date.now();
  let step = Math.floor(now / 30000);
  if (now % 30000 > 25000) step += 1;
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64BE(BigInt(step));
  const h = createHmac('sha1', Buffer.from(bytes)).update(buf).digest();
  const o = h[h.length - 1] & 0xf;
  const bin = ((h[o] & 0x7f) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3];
  return String(bin % 1000000).padStart(6, '0');
}

// Run an arbitrary SQL statement against the test database (used to put
// resources into states the API cannot, e.g. freeze an account). Returns false
// when the mysql client is unavailable.
export function runSql(sql) {
  try {
    execFileSync('mysql', mysqlArgs(sql), { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

// Run a SQL query and return its first cell (trimmed). Returns '' on error.
// Used by tests that assert a database invariant (e.g. ledger consistency).
export function queryScalar(sql) {
  try {
    return execFileSync('mysql', mysqlArgs(sql, ['-N', '-B']), {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
}

// Read the latest unused verification code for an email from the database.
// Tests use this because the gateway no longer returns the code in the response.
export function getVerificationCode(email, purpose = 'SIGNUP') {
  try {
    return execFileSync(
      'mysql',
      mysqlArgs(
        `SELECT code FROM verification_logs WHERE email='${email}' AND purpose='${purpose}' AND is_used=0 ORDER BY id DESC LIMIT 1;`,
        ['-N', '-B'],
      ),
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] },
    ).trim();
  } catch {
    return '';
  }
}

// Insert n users in bulk (for exercising large list responses). Returns false
// when mysql is absent.
export function seedManyUsers(prefix, n, role = 'USER') {
  const values = Array.from(
    { length: n },
    (_, i) =>
      `('${prefix}${i + 1}@test.com',CONCAT('SHA256_',SHA2('secret123',256)),'Bulk ${i + 1}','1990-01-01','VERIFIED','${role}')`,
  ).join(',');
  const sql =
    'INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES ' +
    `${values} ON DUPLICATE KEY UPDATE role='${role}', status='VERIFIED';`;
  try {
    execFileSync('mysql', mysqlArgs(sql), { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

// Ensure the user has one USD savings account (used by transfer tests, whose
// sender is the authenticated token identity). Returns false when mysql is absent.
// Insert a matching opening ledger row for the account, so a seeded balance
// reconciles against the ledger instead of showing up as a false
// reconciliation mismatch (the ledger is the source of truth for balances).
// Idempotent: only inserts when the account has no ledger rows yet.
function seedOpeningLedger(email, currencyId) {
  const sql =
    'INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description) ' +
    "SELECT CONCAT('SEED', a.account_id), a.account_id, a.balance, 'CREDIT', a.currency_id, 'Seed opening' " +
    'FROM accounts a JOIN users u ON u.id = a.user_id ' +
    `WHERE u.email='${email}' AND a.currency_id=${currencyId} ` +
    'AND NOT EXISTS (SELECT 1 FROM ledger l WHERE l.account_id = a.account_id);';
  try {
    execFileSync('mysql', mysqlArgs(sql), { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

// Ensure the user has one account in `currencyId` with `balance` and a matching
// opening ledger row. `firstOnly` keeps the original seedAccount contract (one
// account total); otherwise the guard is per currency (multi-currency fixtures).
export function seedAccountCurrency(email, currencyId, balance, firstOnly = false) {
  const guard = firstOnly
    ? 'NOT EXISTS (SELECT 1 FROM accounts a WHERE a.user_id = u.id)'
    : `NOT EXISTS (SELECT 1 FROM accounts a WHERE a.user_id = u.id AND a.currency_id = ${currencyId})`;
  const sql =
    'INSERT INTO accounts (user_id, currency_id, account_type, balance, status) ' +
    `SELECT u.id, ${currencyId}, 'SAVINGS', ${balance}, 'ACTIVE' FROM users u ` +
    `WHERE u.email='${email}' AND ${guard};`;
  try {
    execFileSync('mysql', mysqlArgs(sql), { stdio: 'ignore' });
  } catch {
    return false;
  }
  return seedOpeningLedger(email, currencyId);
}

export function seedAccount(email, balance = '1000.00') {
  return seedAccountCurrency(email, 1, balance, true);
}

// Refresh exchange-rate timestamps so cross-currency transfers do not fail
// with RATE_STALE when the seeded fixtures are older than RATE_MAX_AGE_SECONDS
// (the core enforces rate freshness). Returns false when mysql is unavailable.
export function refreshExchangeRates() {
  return runSql('UPDATE exchange_rates SET updated_at = NOW();');
}

// Per-file fixture namespace, e.g. `gw-abc123-pid9x-4f2`. Dashes delimit every
// segment and need no LIKE escaping (unlike the old `_` wildcards that forced
// 'ep\_%' quoting). Unique across processes, files, and reruns. When
// TEST_RUN_ID is set (test:db, CI), it becomes the shared stamp so one
// residue check covers the whole run; otherwise each process mints its own
// stamp. The pid separates parallel test files, timestamp+rand separates
// serial reruns.
// Every test-created user must go through uniqueEmail() so cleanupNamespace()
// and the residue check (scripts/check_test_residue.sh) find it.
export function testNamespace(tag) {
  const clean =
    String(tag)
      .replace(/[^a-z0-9-]/gi, '')
      .toLowerCase()
      .slice(0, 12) || 't';
  const shared = String(process.env.TEST_RUN_ID || '')
    .replace(/[^a-z0-9]/gi, '')
    .toLowerCase()
    .slice(0, 24);
  const stamp = shared || `${Date.now().toString(36)}${(process.pid >>> 0).toString(36)}`;
  const rand = Math.floor(Math.random() * 46656)
    .toString(36)
    .padStart(3, '0');
  // Dashes delimit every segment so scripts/check_test_residue.sh can match
  // one run (`%-<stamp>-%`) without touching other runs' fixtures.
  return `${clean}-${stamp}-${rand}`;
}

export function uniqueEmail(ns, name = 'u') {
  const tag =
    String(name)
      .replace(/[^a-z0-9-]/gi, '')
      .toLowerCase()
      .slice(0, 24) || 'u';
  return `${ns}-${tag}@test.com`;
}

// Delete every user in a namespace. Accounts, ledger rows, sessions and
// pending intents cascade away (see gateway.test.js). Returns false when the
// mysql client is unavailable.
export function cleanupNamespace(ns) {
  return runSql(`DELETE FROM users WHERE email LIKE '${ns}-%'`);
}
