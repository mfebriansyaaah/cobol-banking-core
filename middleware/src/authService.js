// Auth session service (gateway orchestration, not business rules).
// Owns all COBOL-backed session/token side effects so responseMappers.js
// stays pure presentation. COBOL remains the source of truth for versions,
// permissions, enrollment, and session rows; this module only orchestrates
// the transport-level sequence (invoke -> sign -> return).
import { randomUUID } from 'node:crypto';
import { invoke } from './invoker.js';
import { signToken, signRefresh, signStepUp, REFRESH_TTL_DAYS } from './auth.js';

export function sanitizeMeta(value, max) {
  return String(value || '')
    .replace(/[^\x20-\x7E]/g, '')
    .replace(/[|;]/g, '_')
    .slice(0, max);
}

export async function listPermissions(email) {
  try {
    const raw = await invoke('LIST_PERMISSIONS', [email]);
    if (!raw.startsWith('SUCCESS|PERMISSIONS')) return [];
    const rows = raw.split('|')[2] || '';
    return rows ? rows.split(';').filter(Boolean) : [];
  } catch {
    return [];
  }
}

export async function tokenVersion(email) {
  try {
    const raw = await invoke('GET_TOKEN_VERSION', [email]);
    const v = Number(String(raw).split('|')[1]);
    return Number.isFinite(v) ? v : 1;
  } catch {
    return 1;
  }
}

async function mfaEnrollRequired(email) {
  return (await invoke('MFA_ENROLL_REQUIRED', [email])) === 'SUCCESS|1';
}

// Complete a successful AUTH_LOGIN: persist the refresh session, emit a
// best-effort login notice, and mint access + refresh tokens.
// Throws when STORE_SESSION is refused so callers can fail closed.
export async function completeLogin(body, input, { req } = {}) {
  const ver = await tokenVersion(input.email);
  const issued = signRefresh({ email: input.email });
  const ua = sanitizeMeta(req && req.headers && req.headers['user-agent'], 120);
  const ip = sanitizeMeta(req && req.ip, 45);
  const stored = await invoke('STORE_SESSION', [issued.jti, input.email, String(REFRESH_TTL_DAYS), issued.jti, ua, ip]);
  if (!String(stored).startsWith('SUCCESS|')) {
    throw new Error(`store refused: ${stored}`);
  }
  // Announce a first sign-in from this fingerprint. Best effort: the login
  // must not fail because the notice could not be queued.
  try {
    await invoke('LOGIN_NOTICE', [input.email, ua, ip]);
  } catch {
    /* best effort */
  }
  // Whether an admin without MFA must enrol next is decided by COBOL; the
  // gateway forwards the flag without reimplementing the admin-role rule.
  const enroll = await mfaEnrollRequired(input.email);
  return {
    ...body,
    token: signToken({ email: input.email, ver, jti: randomUUID(), sid: issued.jti }),
    refreshToken: issued.token,
    mfaEnrollmentRequired: enroll,
    permissions: await listPermissions(input.email),
  };
}

// Complete a successful VERIFY_REAUTH: mint a short-lived step-up proof.
export async function completeStepUp(input) {
  const ver = await tokenVersion(input.email);
  return { data: ['STEP_UP_OK'], stepUpToken: signStepUp({ email: input.email, ver }) };
}

// Complete a successful /auth/refresh: the caller has already consumed the
// old session; persist the rotated session and mint fresh tokens.
// Throws when STORE_SESSION is refused so callers can fail closed.
export async function completeRefresh(payload, { req } = {}) {
  const family = payload.family || payload.jti;
  const ver = await tokenVersion(payload.email);
  const issued = signRefresh({ email: payload.email, family });
  const ua = sanitizeMeta(req && req.headers && req.headers['user-agent'], 120);
  const ip = sanitizeMeta(req && req.ip, 45);
  const stored = await invoke('STORE_SESSION', [issued.jti, payload.email, String(REFRESH_TTL_DAYS), family, ua, ip]);
  if (!String(stored).startsWith('SUCCESS|')) {
    throw new Error(`store refused: ${stored}`);
  }
  try {
    await invoke('LOGIN_NOTICE', [payload.email, ua, ip]);
  } catch {
    /* best effort */
  }
  const enroll = await mfaEnrollRequired(payload.email);
  return {
    data: ['REFRESHED'],
    token: signToken({ email: payload.email, ver, jti: randomUUID(), sid: family }),
    refreshToken: issued.token,
    mfaEnrollmentRequired: enroll,
  };
}
