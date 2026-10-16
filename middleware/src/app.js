import express from 'express';
import helmet from 'helmet';
import { randomUUID } from 'node:crypto';
import { invoke, InvocationTimeout, InvocationError } from './invoker.js';
import { toHttp } from './result.js';
import { buildParams, ValidationError, PATTERNS, assertLineLength } from './validation.js';
import { requireAuth, signToken, signRefresh, verifyRefresh, verifyAccess, signStepUp, verifyStepUp, REFRESH_TTL_DAYS, ACCESS_TTL_SECONDS } from './auth.js';
import { rateLimiter, apiRateLimiter } from './rateLimit.js';
import { createRequestObserver, metricsText, recordError } from './observability.js';
import { getPool } from './pool.js';
import { createMailer } from './mailer.js';
import { createTokenStore } from './tokenStore.js';

const { EMAIL, PASSWORD, NAME, DATE, CODE, ROLE, AMOUNT, INT, LIMIT, KEY, CURRENCY, USER_STATUS, AUDIT_ACTION } = PATTERNS;

// Each route maps an HTTP endpoint to a COBOL action. `fields` lists the
// parameters in the exact order the COBOL module expects them. `tokenIdentity`
// names the field filled from the verified token, never from the request body.
export const ROUTES = [
  { method: 'post', path: '/auth/signup', action: 'REQUEST_SIGNUP', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
    { name: 'name', pattern: NAME, required: true },
    { name: 'dob', pattern: DATE, required: true },
  ], onSuccess: async (body, input, { mailer }) => {
    // Out of band delivery; never returned to the client. A neutral response
    // (no code) is sent when the email is already registered.
    const code = body.data[1];
    if (code) await mailer.sendVerification({ to: input.email, purpose: 'SIGNUP', code });
    return { data: ['USER_CREATED'] };
  } },
  { method: 'post', path: '/auth/verify', action: 'VERIFY_EMAIL', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
  ] },
  { method: 'post', path: '/auth/forgot', action: 'FORGOT_PASSWORD', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
  ], onSuccess: async (body, input, { mailer }) => {
    // Neutral: a code is delivered only when the account exists.
    const code = body.data[1];
    if (code) await mailer.sendVerification({ to: input.email, purpose: 'PASSWORD_RESET', code });
    return { data: ['CODE_SENT'] };
  } },
  { method: 'post', path: '/auth/reset-password', action: 'RESET_PASSWORD', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
  ] },
  { method: 'post', path: '/auth/resend', action: 'RESEND_VERIFICATION', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
  ], onSuccess: async (body, input, { mailer }) => {
    // Neutral: a new code is delivered only when an UNVERIFIED account exists.
    const code = body.data[1];
    if (code) await mailer.sendVerification({ to: input.email, purpose: 'SIGNUP', code });
    return { data: ['CODE_SENT'] };
  } },
  { method: 'post', path: '/auth/login', action: 'AUTH_LOGIN', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
    { name: 'mfaCode', pattern: CODE, required: false },
  ], onSuccess: async (body, input, { req }) => {
    const ver = await tokenVersion(input.email);
    const issued = signRefresh({ email: input.email });
    const ua = sanitizeMeta(req && req.headers && req.headers['user-agent'], 120);
    const ip = sanitizeMeta(req && req.ip, 45);
    await invoke('STORE_SESSION', [issued.jti, input.email, String(REFRESH_TTL_DAYS), issued.jti, ua, ip]);
    // An admin without MFA logs in but may only enrol MFA until it is enabled.
    const enroll = needsEnroll(await invoke('GET_MFA_STATE', [input.email]));
    return {
      ...body,
      token: signToken({ email: input.email, ver, jti: randomUUID(), sid: issued.jti }),
      refreshToken: issued.token,
      mfaEnrollmentRequired: enroll,
    };
  } },

  // Step-up: re-verify the caller's own credentials and mint a short-lived
  // proof required by privileged admin actions. Bearer-authenticated.
  { method: 'post', path: '/auth/step-up', action: 'VERIFY_REAUTH', tokenIdentity: 'email', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
    { name: 'mfaCode', pattern: CODE, required: false },
  ], onSuccess: async (body, input) => {
    const ver = await tokenVersion(input.email);
    return { data: ['STEP_UP_OK'], stepUpToken: signStepUp({ email: input.email, ver }) };
  } },

  { method: 'get', path: '/users', action: 'LIST_USERS', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'role', pattern: ROLE, required: false },
  ], onSuccess: async (body) => {
    // data: ['LIST_DONE', total, 'id:email:name:role:status;...']
    const total = Number(body.data[1]);
    const users = String(body.data[2] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [id, email, name, role, status] = row.split(':');
        return { id, email, name, role, status };
      });
    return { data: ['USERS'], total, users };
  } },
  { method: 'get', path: '/users/:email', action: 'GET_USER', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body) => {
    // data: ['USER', id, email, name, status, role, createdAt]
    const [id, email, name, status, role, createdAt] = body.data.slice(1);
    return { data: ['USER'], user: { id, email, name, status, role, createdAt } };
  } },
  { method: 'get', path: '/wallet/balance', action: 'CHECK_BALANCE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body) => {
    // Every account, parsed from "iso:balance:status" rows.
    const balances = String(body.data[1] || '')
      .split(';')
      .filter(Boolean)
      .map((row) => {
        const [currency, balance, status] = row.split(':');
        return { currency, balance, status };
      });
    return { data: ['BALANCES'], balances };
  } },
  { method: 'post', path: '/wallet/transfer', action: 'TRANSFER', tokenIdentity: 'from', fields: [
    { name: 'from', pattern: EMAIL, required: true },
    { name: 'to', pattern: EMAIL, required: true },
    { name: 'amount', pattern: AMOUNT, required: true },
    { name: 'idempotencyKey', pattern: KEY, required: true },
    { name: 'fromCurrency', pattern: CURRENCY, required: false },
    { name: 'toCurrency', pattern: CURRENCY, required: false },
  ] },
  { method: 'get', path: '/transactions/:ref', action: 'TX_STATUS', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: KEY, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'sender', pattern: EMAIL, required: false },
  ] },
  { method: 'post', path: '/transactions/:ref/reverse', action: 'REVERSE_TRANSFER', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'ref', pattern: KEY, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'sender', pattern: EMAIL, required: false },
  ] },

  { method: 'get', path: '/profile', action: 'GET_DASHBOARD', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body) => {
    // data: ['DASHBOARD', email, name, status, role, dob, createdAt, accounts]
    const [email, name, status, role, dob, createdAt, accounts = ''] = body.data.slice(1);
    const balances = accounts
      ? accounts.split(';').map((row) => {
          const [currency, balance] = row.split(':');
          return { currency, balance };
        })
      : [];
    return { data: ['PROFILE'], profile: { email, name, status, role, dob, createdAt }, accounts: balances };
  } },
  { method: 'patch', path: '/profile', action: 'UPDATE_PROFILE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'name', pattern: NAME, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'dob', pattern: DATE, required: false },
  ] },
  { method: 'post', path: '/profile/deactivate', action: 'DEACTIVATE_ACCOUNT', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/user-status', action: 'SET_USER_STATUS', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'status', pattern: USER_STATUS, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/unlock', action: 'UNLOCK_USER', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/mfa-reset', action: 'ADMIN_RESET_MFA', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/profile/email/request', action: 'REQ_EMAIL_CHANGE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'newEmail', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
  ], onSuccess: async (body, input, { mailer }) => {
    // Neutral: a code is delivered only when the new address is free.
    const code = body.data[1];
    if (code) await mailer.sendVerification({ to: input.newEmail, purpose: 'EMAIL_CHANGE', code });
    return { data: ['CODE_SENT'] };
  } },
  { method: 'post', path: '/profile/email/confirm', action: 'CONFIRM_EMAIL_CHANGE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'newEmail', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body, input, { mailer }) => {
    // Notify the address being abandoned.
    await mailer.sendNotice({
      to: input.email,
      subject: 'Your account email was changed',
      text: `Your account email was changed to ${input.newEmail}. If this was not you, contact support.`,
    });
    return { data: ['EMAIL_CHANGED'] };
  } },
  { method: 'post', path: '/profile/password', action: 'CHANGE_PASSWORD', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'currentPassword', pattern: PASSWORD, required: true },
    { name: 'newPassword', pattern: PASSWORD, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/mfa/enroll', action: 'MFA_ENROLL_BEGIN', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body, input) => {
    // The secret is shown once so the user can add it to their authenticator.
    const secret = body.data[1];
    const issuer = process.env.MFA_ISSUER || 'CobolBank';
    const label = encodeURIComponent(`${issuer}:${input.email}`);
    const otpauth = `otpauth://totp/${label}?secret=${secret}&issuer=${encodeURIComponent(issuer)}&algorithm=SHA1&digits=6&period=30`;
    return { data: ['MFA_SECRET'], secret, otpauth };
  } },
  { method: 'post', path: '/mfa/confirm', action: 'MFA_ENROLL_CONFIRM', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/mfa/disable', action: 'MFA_DISABLE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'get', path: '/sessions', action: 'LIST_SESSIONS', tokenIdentity: 'actor', tokenSid: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'sid', pattern: KEY, required: false },
  ] },
  { method: 'post', path: '/sessions/revoke', action: 'REVOKE_USER_SESSION', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'sessionId', pattern: KEY, required: true },
  ] },
  { method: 'post', path: '/sessions/revoke-all', action: 'REVOKE_ALL_SESSIONS', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'get', path: '/admin/role', action: 'CHECK_ROLE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'role', pattern: ROLE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  // Read-only consistency check: every account balance against its ledger sum.
  // Requires a SUPER_ADMIN actor, taken from the verified token (not the body).
  { method: 'get', path: '/admin/reconcile', action: 'RECONCILE', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/role', action: 'CHANGE_ROLE', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'role', pattern: ROLE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/audit/archive', action: 'ARCHIVE_AUDIT', tokenIdentity: 'actor', stepUp: true, fields: [
    { name: 'days', pattern: INT, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  // Read-only audit trail (SUPER_ADMIN): optional action/email filters + paging.
  { method: 'get', path: '/admin/audit', action: 'LIST_AUDIT', tokenIdentity: 'actor', fields: [
    { name: 'actor', pattern: EMAIL, required: true },
    { name: 'action', pattern: AUDIT_ACTION, required: false },
    { name: 'email', pattern: EMAIL, required: false },
    { name: 'limit', pattern: LIMIT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ] },
];

// Keep client-supplied session metadata to safe, bounded text: strip control
// characters and the input-line/column separators (| and ;) so a user-agent
// cannot corrupt the session-list row format, and cap the length.
function sanitizeMeta(value, max) {
  return String(value || '')
    .replace(/[^\x20-\x7E]/g, '')
    .replace(/[|;]/g, '_')
    .slice(0, max);
}

// Whether a freshly authenticated account is an admin that still lacks MFA and
// therefore gets a limited "enroll" access token (ADR 0020 follow-up).
function needsEnroll(mfaState) {
  const [, role, mfa] = String(mfaState).split('|');
  return (role === 'SUPER_ADMIN' || role === 'MANAGER') && mfa !== '1';
}

async function tokenVersion(email) {
  try {
    const raw = await invoke('GET_TOKEN_VERSION', [email]);
    const v = Number(String(raw).split('|')[1]);
    return Number.isFinite(v) ? v : 1;
  } catch {
    return 1;
  }
}

// The access token carries the user's token version and its own jti; a mismatch
// (or a denylisted jti) means it was revoked since it was issued.
export function buildRouter({ mailer, tokenStore } = {}) {
  const router = express.Router();
  const authLimiter = rateLimiter();
  const apiLimiter = apiRateLimiter();

  const requireActiveToken = async (req, res, next) => {
    try {
      const u = req.user || {};
      const ok = await tokenStore.isActive({ email: u.email || '', ver: u.ver, jti: u.jti });
      if (ok) return next();
      return res.status(401).json({ error: 'TOKEN_REVOKED' });
    } catch (err) {
      return next(err);
    }
  };

  // Role gate for operator-only endpoints (checked live in COBOL). CHECK_ROLE
  // allows the actor to test their own role, so it works as a self role check.
  const requireRole = (role) => async (req, res, next) => {
    try {
      const email = (req.user && req.user.email) || '';
      const raw = await invoke('CHECK_ROLE', [email, role, email]);
      if (raw === 'SUCCESS|ROLE_OK') return next();
      return res.status(403).json({ error: 'FORBIDDEN' });
    } catch (err) {
      return next(err);
    }
  };

  // Step-up gate for privileged admin writes: require a fresh, short-lived
  // proof (from POST /auth/step-up) bound to this caller and its token version.
  const requireStepUp = (req, res, next) => {
    const token = req.get('x-step-up') || (req.body && req.body.stepUpToken) || '';
    if (!token) return res.status(401).json({ error: 'STEP_UP_REQUIRED' });
    let payload;
    try {
      payload = verifyStepUp(token);
    } catch {
      return res.status(401).json({ error: 'STEP_UP_REQUIRED' });
    }
    const u = req.user || {};
    if (payload.email !== u.email || String(payload.ver) !== String(u.ver)) {
      return res.status(401).json({ error: 'STEP_UP_REQUIRED' });
    }
    return next();
  };

  // Deep health: confirm the COBOL core can reach the database. Rate-limited:
  // it is public and performs a COBOL/DB round-trip, so it must not be an
  // anonymous amplification vector.
  router.get('/health', apiLimiter, async (_req, res) => {
    const t0 = Date.now();
    try {
      const raw = await invoke('PING', []);
      const ms = Date.now() - t0;
      res.set('X-Cobol-Ms', String(ms));
      if (raw === 'SUCCESS|PONG') {
        return res.json({ status: 'ok', db: 'up', data: ['PONG'] });
      }
      return res.status(503).json({ status: 'degraded', db: 'down' });
    } catch {
      res.set('X-Cobol-Ms', String(Date.now() - t0));
      return res.status(503).json({ status: 'degraded', db: 'down' });
    }
  });

  // Liveness: the process is up. No dependencies — never flaps on a DB blip.
  router.get('/live', (_req, res) => res.json({ status: 'alive' }));

  // Readiness: dependencies usable (DB reachable, pool has a worker when
  // pooling is on). Public like a readiness probe must be, so it is
  // rate-limited and its result is cached for a short window (PROBE_CACHE_MS)
  // to bound the DB round-trips an anonymous caller can trigger.
  let readyCache = null; // { at, status, body }
  router.get('/ready', apiLimiter, async (_req, res) => {
    const ttl = Number(process.env.PROBE_CACHE_MS || 1000);
    const now = Date.now();
    if (readyCache && now - readyCache.at < ttl) {
      return res.status(readyCache.status).json(readyCache.body);
    }
    const checks = {};
    try {
      const raw = await invoke('PING', []);
      checks.db = raw === 'SUCCESS|PONG' ? 'up' : 'down';
    } catch {
      checks.db = 'down';
    }
    const pool = getPool();
    checks.pool = pool ? (pool.stats().size > 0 ? 'up' : 'down') : 'off';
    // Informational only: delivery is best-effort, so a missing SMTP does not
    // make the instance unready — but it is surfaced here.
    checks.mailer = process.env.SMTP_HOST ? 'configured' : 'unset';
    const ok = checks.db === 'up' && checks.pool !== 'down';
    const status = ok ? 200 : 503;
    const body = { status: ok ? 'ready' : 'not_ready', checks };
    readyCache = { at: now, status, body };
    return res.status(status).json(body);
  });

  // Prometheus-style counters (support only). Authenticated to keep the
  // surface closed; scrapers send a bearer token.
  router.get('/metrics', apiLimiter, requireAuth, requireActiveToken, requireRole('SUPER_ADMIN'), (_req, res) => {
    res.type('text/plain').send(metricsText());
  });

  // Pure transport: exchange a refresh token for a new access token. The old
  // refresh token is consumed atomically; a replay is detected as reuse.
  router.post('/auth/refresh', authLimiter, async (req, res) => {
    try {
      const payload = verifyRefresh((req.body && req.body.refreshToken) || '');
      const consume = await invoke('CONSUME_SESSION', [payload.jti || '']);
      if (consume !== 'SUCCESS|SESSION_CONSUMED') {
        return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
      }
      const family = payload.family || payload.jti;
      const ver = await tokenVersion(payload.email);
      const issued = signRefresh({ email: payload.email, family });
      const ua = sanitizeMeta(req.headers && req.headers['user-agent'], 120);
      const ip = sanitizeMeta(req.ip, 45);
      await invoke('STORE_SESSION', [issued.jti, payload.email, String(REFRESH_TTL_DAYS), family, ua, ip]);
      const enroll = needsEnroll(await invoke('GET_MFA_STATE', [payload.email]));
      return res.json({
        data: ['REFRESHED'],
        token: signToken({ email: payload.email, ver, jti: randomUUID(), sid: family }),
        refreshToken: issued.token,
        mfaEnrollmentRequired: enroll,
      });
    } catch {
      return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
    }
  });

  // Per-device logout: revoke the presented refresh session and, when the
  // bearer is also presented, deny that access token. Other devices are
  // unaffected — use POST /sessions/revoke-all to log out everywhere.
  router.post('/auth/logout', authLimiter, async (req, res) => {
    try {
      const payload = verifyRefresh((req.body && req.body.refreshToken) || '');
      await invoke('REVOKE_SESSION', [payload.jti || '']);
      const header = req.headers.authorization || '';
      const [scheme, token] = header.split(' ');
      if (scheme === 'Bearer' && token) {
        const u = verifyAccess(token);
        if (u && u.jti) {
          await tokenStore.revoke({ jti: u.jti, email: u.email, ttlSeconds: ACCESS_TTL_SECONDS });
        }
      }
      return res.json({ data: ['LOGGED_OUT'] });
    } catch {
      return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
    }
  });

  // Revoke just the presented access token (per-token denylist), leaving other
  // sessions of the same user valid.
  router.post('/auth/revoke', apiLimiter, requireAuth, requireActiveToken, async (req, res, next) => {
    try {
      await tokenStore.revoke({ jti: req.user.jti, email: req.user.email, ttlSeconds: ACCESS_TTL_SECONDS });
      return res.json({ data: ['TOKEN_REVOKED'] });
    } catch (err) {
      return next(err);
    }
  });

  for (const route of ROUTES) {
    const handler = async (req, res, next) => {
      try {
        const input = { ...req.params, ...req.query, ...req.body };
        if (req.headers['idempotency-key']) {
          input.idempotencyKey = req.headers['idempotency-key'];
        }
        // Identity fields (actor, or the transfer sender) trust the token only.
        if (route.tokenIdentity) {
          input[route.tokenIdentity] = (req.user && req.user.email) || '';
        }
        // Session ids ("sid") are the token's refresh-session family; used to
        // mark the caller's own session in the list.
        if (route.tokenSid) {
          input.sid = (req.user && req.user.sid) || '';
        }
        const params = buildParams(route, input);
        assertLineLength(route.action, params);
        const t0 = Date.now();
        const raw = await invoke(route.action, params);
        res.set('X-Cobol-Ms', String(Date.now() - t0));
        const { status, body } = toHttp(raw);
        if (status !== 200 && body && body.error) {
          res.locals.errorCode = body.error;
          recordError(body.error);
        }
        if (status === 200 && route.onSuccess) {
          return res.status(status).json(await route.onSuccess(body, input, { mailer, req }));
        }
        return res.status(status).json(body);
      } catch (err) {
        return next(err);
      }
    };
    const chain = [];
    if (route.path.startsWith('/auth')) chain.push(authLimiter);
    else chain.push(apiLimiter);
    if (!route.public) chain.push(requireAuth);
    if (!route.public) chain.push(requireActiveToken);
    if (route.stepUp) chain.push(requireStepUp);
    chain.push(handler);
    router[route.method](route.path, ...chain);
  }

  return router;
}

// Advisory misconfiguration check for the rate-limit key: without TRUST_PROXY
// every client behind a load balancer shares one IP (the limiter collapses
// into self-DoS), while TRUST_PROXY=true trusts any X-Forwarded-For header and
// lets callers spoof their key (the limiter is bypassed). Returns a warning
// message, or null when the setting looks sound.
export function trustProxyWarning() {
  const v = process.env.TRUST_PROXY;
  if (!v) {
    return 'TRUST_PROXY is not set; behind a proxy every client shares one rate-limit key (set it to the hop count, e.g. 1)';
  }
  if (v === 'true') {
    return 'TRUST_PROXY=true trusts any X-Forwarded-For header, letting callers spoof the rate-limit key (use a hop count or subnet instead)';
  }
  return null;
}

export function buildApp({ logger = null, mailer = null, tokenStore = null } = {}) {
  const app = express();
  // Behind a proxy the client IP (and so the rate-limit key) must come from the
  // forwarded headers. Off unless configured.
  app.set('trust proxy', process.env.TRUST_PROXY || false);
  app.use(helmet());
  app.use(createRequestObserver({ logger }));
  // Legitimate bodies are under a kilobyte (short credential/profile fields);
  // reject anything larger before it costs parsing memory or reaches COBOL.
  app.use(express.json({ limit: '20kb' }));
  app.use(buildRouter({ mailer: mailer || createMailer({ logger }), tokenStore: tokenStore || createTokenStore() }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    let status = 500;
    let code = 'INTERNAL';
    if (err instanceof ValidationError) {
      status = 400;
      code = 'INVALID_PARAMETER';
    } else if (err instanceof InvocationTimeout) {
      status = 504;
      code = 'GATEWAY_TIMEOUT';
    } else if (err instanceof InvocationError) {
      status = 502;
      code = 'COBOL_UNAVAILABLE';
    } else if (err.status === 413 || err.type === 'entity.too.large') {
      status = 413;
      code = 'BODY_TOO_LARGE';
    }
    res.locals.errorCode = code;
    recordError(code);
    if (logger) {
      logger({
        ts: new Date().toISOString(),
        level: 'error',
        event: 'gateway_error',
        code,
        status,
        message: err && err.message,
        stack: err && err.stack,
      });
    }
    if (err instanceof ValidationError) {
      return res.status(status).json({ error: code, field: err.field });
    }
    return res.status(status).json({ error: code });
  });
  return app;
}
