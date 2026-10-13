// Test support: seed a VERIFIED user with the shared test password so the
// gateway suites can exercise admin-only and self-or-admin paths. Returns false
// when the mysql client is unavailable, letting callers skip.
import { execFileSync } from 'node:child_process';

export function seedUser(email, role = 'USER') {
  const u = process.env.DB_USER ?? 'cobol_user';
  const p = process.env.DB_PASS ?? 'cobol_pass';
  const n = process.env.DB_NAME ?? 'cobol_db';
  const sql =
    'INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES ' +
    `('${email}',CONCAT('SHA256_',SHA2('secret123',256)),'Test User','1990-01-01','VERIFIED','${role}') ` +
    `ON DUPLICATE KEY UPDATE role='${role}', status='VERIFIED', password_hash=VALUES(password_hash);`;
  try {
    execFileSync('mysql', ['-u', u, `-p${p}`, n, '-e', sql], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

// Read the latest unused verification code for an email from the database.
// Tests use this because the gateway no longer returns the code in the response.
export function getVerificationCode(email, purpose = 'SIGNUP') {
  const u = process.env.DB_USER ?? 'cobol_user';
  const p = process.env.DB_PASS ?? 'cobol_pass';
  const n = process.env.DB_NAME ?? 'cobol_db';
  try {
    return execFileSync('mysql', ['-u', u, `-p${p}`, n, '-N', '-B', '-e',
      `SELECT code FROM verification_logs WHERE email='${email}' AND purpose='${purpose}' AND is_used=0 ORDER BY id DESC LIMIT 1;`],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    return '';
  }
}

// Insert n users in bulk (for exercising large list responses). Returns false
// when mysql is absent.
export function seedManyUsers(prefix, n, role = 'USER') {
  const u = process.env.DB_USER ?? 'cobol_user';
  const p = process.env.DB_PASS ?? 'cobol_pass';
  const db = process.env.DB_NAME ?? 'cobol_db';
  const values = Array.from({ length: n }, (_, i) =>
    `('${prefix}${i + 1}@test.com',CONCAT('SHA256_',SHA2('secret123',256)),'Bulk ${i + 1}','1990-01-01','VERIFIED','${role}')`,
  ).join(',');
  const sql =
    'INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES ' +
    `${values} ON DUPLICATE KEY UPDATE role='${role}', status='VERIFIED';`;
  try {
    execFileSync('mysql', ['-u', u, `-p${p}`, db, '-e', sql], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

// Ensure the user has one USD savings account (used by transfer tests, whose
// sender is the authenticated token identity). Returns false when mysql is absent.
export function seedAccount(email, balance = '1000.00') {
  const u = process.env.DB_USER ?? 'cobol_user';
  const p = process.env.DB_PASS ?? 'cobol_pass';
  const n = process.env.DB_NAME ?? 'cobol_db';
  const sql =
    'INSERT INTO accounts (user_id, currency_id, account_type, balance, status) ' +
    `SELECT u.id, 1, 'SAVINGS', ${balance}, 'ACTIVE' FROM users u ` +
    `WHERE u.email='${email}' AND NOT EXISTS (SELECT 1 FROM accounts a WHERE a.user_id=u.id);`;
  try {
    execFileSync('mysql', ['-u', u, `-p${p}`, n, '-e', sql], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}
