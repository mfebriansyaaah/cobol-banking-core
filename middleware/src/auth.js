import jwt from 'jsonwebtoken';
import { randomUUID } from 'node:crypto';

const SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';
const EXPIRES_IN = process.env.JWT_EXPIRES_IN || '15m';
const REFRESH_SECRET = process.env.REFRESH_SECRET || 'dev-refresh-secret-change-me';
const REFRESH_EXPIRES_IN = process.env.REFRESH_EXPIRES_IN || '7d';

// Refresh-token lifetime in whole days (mirrors REFRESH_EXPIRES_IN for storage).
export const REFRESH_TTL_DAYS = Number(process.env.REFRESH_TTL_DAYS || 7);

const DEV_JWT_SECRET = 'dev-secret-change-me';
const DEV_REFRESH_SECRET = 'dev-refresh-secret-change-me';

// Refuse to run in production with the development secrets.
export function assertSecureConfig() {
  if (process.env.NODE_ENV !== 'production') return;
  const problems = [];
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET === DEV_JWT_SECRET) problems.push('JWT_SECRET');
  if (!process.env.REFRESH_SECRET || process.env.REFRESH_SECRET === DEV_REFRESH_SECRET) problems.push('REFRESH_SECRET');
  if (problems.length > 0) {
    throw new Error(`refusing to start in production: set ${problems.join(', ')} to a strong, non-default value`);
  }
}

export function signToken(payload) {
  return jwt.sign(payload, SECRET, { expiresIn: EXPIRES_IN });
}

/** Issue a refresh token carrying a jti (server-side revocable id). */
export function signRefresh(payload, jti = randomUUID()) {
  const token = jwt.sign({ ...payload, jti }, REFRESH_SECRET, { expiresIn: REFRESH_EXPIRES_IN });
  return { token, jti };
}

export function verifyRefresh(token) {
  return jwt.verify(token, REFRESH_SECRET);
}

/** Express middleware: require a valid bearer token. */
export function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'MISSING_TOKEN' });
  }
  try {
    req.user = jwt.verify(token, SECRET);
    return next();
  } catch {
    return res.status(401).json({ error: 'INVALID_TOKEN' });
  }
}
