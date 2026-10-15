import express from 'express';
import helmet from 'helmet';
import { randomUUID } from 'node:crypto';
import { invoke, InvocationTimeout, InvocationError } from './invoker.js';
import { toHttp } from './result.js';
import { buildParams, ValidationError, PATTERNS, assertLineLength } from './validation.js';
import { requireAuth, signToken, signRefresh, verifyRefresh, verifyAccess, REFRESH_TTL_DAYS, ACCESS_TTL_SECONDS } from './auth.js';
import { rateLimiter, apiRateLimiter } from './rateLimit.js';
import { createRequestObserver, metricsText } from './observability.js';
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
    return { ...body, token: signToken({ email: input.email, ver, jti: randomUUID(), sid: issued.jti }), refreshToken: issued.token };
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
  { method: 'post', path: '/transactions/:ref/reverse', action: 'REVERSE_TRANSFER', tokenIdentity: 'actor', fields: [
    { name: 'ref', pattern: KEY, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
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
  { method: 'post', path: '/admin/user-status', action: 'SET_USER_STATUS', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'status', pattern: USER_STATUS, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/unlock', action: 'UNLOCK_USER', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/mfa-reset', action: 'ADMIN_RESET_MFA', tokenIdentity: 'actor', fields: [
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
  { method: 'post', path: '/admin/role', action: 'CHANGE_ROLE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'role', pattern: ROLE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/admin/audit/archive', action: 'ARCHIVE_AUDIT', tokenIdentity: 'actor', fields: [
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

  // Deep health: confirm the COBOL core can reach the database.
  router.get('/health', async (_req, res) => {
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
      return res.json({
        data: ['REFRESHED'],
        token: signToken({ email: payload.email, ver, jti: randomUUID(), sid: family }),
        refreshToken: issued.token,
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
    chain.push(handler);
    router[route.method](route.path, ...chain);
  }

  return router;
}

export function buildApp({ logger = null, mailer = null, tokenStore = null } = {}) {
  const app = express();
  // Behind a proxy the client IP (and so the rate-limit key) must come from the
  // forwarded headers. Off unless configured.
  app.set('trust proxy', process.env.TRUST_PROXY || false);
  app.use(helmet());
  app.use(createRequestObserver({ logger }));
  app.use(express.json());
  app.use(buildRouter({ mailer: mailer || createMailer({ logger }), tokenStore: tokenStore || createTokenStore() }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err instanceof ValidationError) {
      return res.status(400).json({ error: 'INVALID_PARAMETER', field: err.field });
    }
    if (err instanceof InvocationTimeout) {
      return res.status(504).json({ error: 'GATEWAY_TIMEOUT' });
    }
    if (err instanceof InvocationError) {
      return res.status(502).json({ error: 'COBOL_UNAVAILABLE' });
    }
    return res.status(500).json({ error: 'INTERNAL' });
  });
  return app;
}
