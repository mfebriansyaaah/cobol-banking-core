import jwt from 'jsonwebtoken';
import { randomUUID } from 'node:crypto';

const SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';
const EXPIRES_IN = process.env.JWT_EXPIRES_IN || '15m';
const REFRESH_SECRET = process.env.REFRESH_SECRET || 'dev-refresh-secret-change-me';
const REFRESH_EXPIRES_IN = process.env.REFRESH_EXPIRES_IN || '7d';

// Only HMAC-SHA256 is accepted, on both sign and verify. Pinning the
// algorithm on verification blocks algorithm-confusion attacks (e.g. a token
// claiming `alg: none` or a different family).
const ALGORITHM = 'HS256';

// Tokens are bound to an issuer and audience so a token minted for one
// deployment cannot be replayed against another.
const ISSUER = process.env.JWT_ISSUER || 'cobol-banking-core';
const AUDIENCE = process.env.JWT_AUDIENCE || 'cobol-banking-api';
const JWT_CLAIMS = { issuer: ISSUER, audience: AUDIENCE };
const VERIFY_OPTS = { algorithms: [ALGORITHM], ...JWT_CLAIMS };

// Refresh-token lifetime in whole days (mirrors REFRESH_EXPIRES_IN for storage).
export const REFRESH_TTL_DAYS = Number(process.env.REFRESH_TTL_DAYS || 7);

// Overlapping secret rotation: *_PREVIOUS holds the pre-rotation value so
// tokens minted before a restart still verify during a bounded overlap.
// Signing always uses the current secret; verification tries current, then
// previous. The previous value is read per call (not captured at import) so
// tests and rotation tooling can stage it at any time.
//
// The overlap is time-bounded: a previous secret is accepted only until its
// *_PREVIOUS_UNTIL (unix epoch seconds). Without that bound the old value
// would keep verifying (and could keep signing) indefinitely, which is the
// risk rotation exists to close.
const PREVIOUS_UNTIL = {
  JWT_SECRET_PREVIOUS: 'JWT_SECRET_PREVIOUS_UNTIL',
  REFRESH_SECRET_PREVIOUS: 'REFRESH_SECRET_PREVIOUS_UNTIL',
};

/** Unix epoch seconds from *_PREVIOUS_UNTIL, or null when unset/invalid. */
function previousUntil(name) {
  const raw = process.env[name];
  if (raw === undefined || String(raw).trim() === '') return null;
  const text = String(raw).trim();
  if (!/^\d+$/.test(text)) return null;
  return Number(text);
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

/** True while the staged previous secret may still verify tokens. */
function previousActive(previous, untilName) {
  const until = previousUntil(untilName);
  if (until === null) return false;
  return nowSeconds() < until;
}

function candidates(current, previousName) {
  const previous = process.env[previousName] || '';
  if (!previous || previous === current) return [current];
  if (!previousActive(previous, PREVIOUS_UNTIL[previousName])) return [current];
  return [current, previous];
}

function verifyWithAny(token, current, previousName) {
  let lastErr;
  for (const secret of candidates(current, previousName)) {
    try {
      return jwt.verify(token, secret, VERIFY_OPTS);
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr;
}

const DEV_JWT_SECRET = 'dev-secret-change-me';
const DEV_REFRESH_SECRET = 'dev-refresh-secret-change-me';
const MIN_SECRET_LENGTH = 32;

// Development defaults baked into the C bridge (cobol/src/sql_bridge.c) and
// middleware/.env.example. Production must set these explicitly: a deployment
// that silently inherits them would run against the development database with
// the development account.
const DEV_DB_DEFAULTS = {
  DB_USER: 'cobol_user',
  DB_PASS: 'cobol_pass',
  DB_NAME: 'cobol_db',
};
// Must be present in production (any value); there is no safe silent default
// for where the database lives.
const REQUIRED_DB_VARS = ['DB_HOST'];

// Refuse to run in production with development, short, or identical secrets,
// or with database credentials left at their development defaults.
export function assertSecureConfig() {
  if (process.env.NODE_ENV !== 'production') return;
  const problems = [];
  const accessSecret = process.env.JWT_SECRET || '';
  const refreshSecret = process.env.REFRESH_SECRET || '';
  if (!accessSecret || accessSecret === DEV_JWT_SECRET) problems.push('JWT_SECRET');
  else if (accessSecret.length < MIN_SECRET_LENGTH) problems.push(`JWT_SECRET (min ${MIN_SECRET_LENGTH} chars)`);
  if (!refreshSecret || refreshSecret === DEV_REFRESH_SECRET) problems.push('REFRESH_SECRET');
  else if (refreshSecret.length < MIN_SECRET_LENGTH) problems.push(`REFRESH_SECRET (min ${MIN_SECRET_LENGTH} chars)`);
  const accessPrev = process.env.JWT_SECRET_PREVIOUS || '';
  const refreshPrev = process.env.REFRESH_SECRET_PREVIOUS || '';
  if (accessPrev) {
    if (accessPrev === DEV_JWT_SECRET) problems.push('JWT_SECRET_PREVIOUS');
    else if (accessPrev.length < MIN_SECRET_LENGTH)
      problems.push(`JWT_SECRET_PREVIOUS (min ${MIN_SECRET_LENGTH} chars)`);
  }
  if (refreshPrev) {
    if (refreshPrev === DEV_REFRESH_SECRET) problems.push('REFRESH_SECRET_PREVIOUS');
    else if (refreshPrev.length < MIN_SECRET_LENGTH)
      problems.push(`REFRESH_SECRET_PREVIOUS (min ${MIN_SECRET_LENGTH} chars)`);
  }
  // A staged previous secret must carry its overlap deadline: without one the
  // old value would be accepted (and could sign) forever.
  for (const [previousName, untilName] of Object.entries(PREVIOUS_UNTIL)) {
    if (!process.env[previousName]) continue;
    const until = previousUntil(untilName);
    if (until === null || until <= 0) {
      problems.push(`${untilName} (required while ${previousName} is set)`);
    }
  }
  // Every configured secret must be distinct: a value shared across the
  // family would let a token signed for one purpose verify as another.
  const family = [
    ['JWT_SECRET', accessSecret],
    ['JWT_SECRET_PREVIOUS', accessPrev],
    ['REFRESH_SECRET', refreshSecret],
    ['REFRESH_SECRET_PREVIOUS', refreshPrev],
  ];
  for (let i = 0; i < family.length; i += 1) {
    for (let j = i + 1; j < family.length; j += 1) {
      const [leftName, left] = family[i];
      const [rightName, right] = family[j];
      if (left && right && left === right) {
        problems.push(`${rightName} must differ from ${leftName}`);
      }
    }
  }
  for (const [name, devDefault] of Object.entries(DEV_DB_DEFAULTS)) {
    const value = process.env[name] || '';
    if (!value) problems.push(name);
    else if (value === devDefault) problems.push(`${name} (development default)`);
  }
  for (const name of REQUIRED_DB_VARS) {
    if (!(process.env[name] || '')) problems.push(name);
  }
  if (problems.length > 0) {
    throw new Error(`refusing to start in production: set ${problems.join(', ')} to a strong, non-default value`);
  }
}

export function signToken(payload) {
  return jwt.sign(payload, SECRET, { expiresIn: EXPIRES_IN, algorithm: ALGORITHM, ...JWT_CLAIMS });
}

// Access-token lifetime in seconds (for the per-token denylist expiry).
function parseSeconds(spec, fallback) {
  const m = /^(\d+)\s*([smhd])?$/.exec(String(spec || '').trim());
  if (!m) return fallback;
  const mult = { s: 1, m: 60, h: 3600, d: 86400 }[m[2] || 's'];
  return Number(m[1]) * mult;
}
export const ACCESS_TTL_SECONDS = parseSeconds(EXPIRES_IN, 900);

/** Issue a refresh token carrying a jti (server-side revocable id). */
export function signRefresh(payload, jti = randomUUID()) {
  const token = jwt.sign({ ...payload, jti }, REFRESH_SECRET, {
    expiresIn: REFRESH_EXPIRES_IN,
    algorithm: ALGORITHM,
    ...JWT_CLAIMS,
  });
  return { token, jti };
}

export function verifyRefresh(token) {
  return verifyWithAny(token, REFRESH_SECRET, 'REFRESH_SECRET_PREVIOUS');
}

/** Verify an access token, returning its payload or null (never throws). */
export function verifyAccess(token) {
  try {
    const p = verifyWithAny(token, SECRET, 'JWT_SECRET_PREVIOUS');
    return p.purpose ? null : p;
  } catch {
    return null;
  }
}

// Step-up (re-authentication) tokens: short-lived proofs that the caller just
// re-verified their password (and MFA where enabled). Required for privileged
// admin actions. A distinct `purpose` claim stops one being used as an access
// token, and vice versa.
export const STEP_UP_TTL_SECONDS = parseSeconds(process.env.STEP_UP_TTL_SECONDS || '300', 300);

export function signStepUp(payload) {
  return jwt.sign({ ...payload, purpose: 'step-up' }, SECRET, {
    expiresIn: STEP_UP_TTL_SECONDS,
    algorithm: ALGORITHM,
    ...JWT_CLAIMS,
  });
}

export function verifyStepUp(token) {
  const p = verifyWithAny(token, SECRET, 'JWT_SECRET_PREVIOUS');
  if (p.purpose !== 'step-up') throw new Error('not a step-up token');
  return p;
}

/** Express middleware: require a valid bearer token. */
export function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'MISSING_TOKEN' });
  }
  try {
    req.user = verifyWithAny(token, SECRET, 'JWT_SECRET_PREVIOUS');
    // A step-up (or any other purpose-tagged) token is not an access token.
    if (req.user.purpose) {
      return res.status(401).json({ error: 'INVALID_TOKEN' });
    }
    return next();
  } catch {
    return res.status(401).json({ error: 'INVALID_TOKEN' });
  }
}
