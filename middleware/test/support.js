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
