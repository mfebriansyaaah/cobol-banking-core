import express from 'express';
import helmet from 'helmet';
import { invoke, InvocationTimeout, InvocationError } from './invoker.js';
import { toHttp } from './result.js';
import { buildParams, ValidationError, PATTERNS, assertLineLength } from './validation.js';
import { requireAuth, signToken, signRefresh, verifyRefresh, REFRESH_TTL_DAYS } from './auth.js';
import { rateLimiter, apiRateLimiter } from './rateLimit.js';
import { createRequestObserver, metricsText } from './observability.js';
import { createMailer } from './mailer.js';

const { EMAIL, PASSWORD, NAME, DATE, CODE, ROLE, AMOUNT, INT, KEY } = PATTERNS;

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
    // The code is delivered out of band; it is never returned to the client.
    await mailer.sendVerification({ to: input.email, purpose: 'SIGNUP', code: body.data[1] });
    return { data: ['USER_CREATED'] };
  } },
  { method: 'post', path: '/auth/verify', action: 'VERIFY_EMAIL', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
  ] },
  { method: 'post', path: '/auth/login', action: 'AUTH_LOGIN', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
  ], onSuccess: async (body, input) => {
    const ver = await tokenVersion(input.email);
    const issued = signRefresh({ email: input.email });
    await invoke('STORE_SESSION', [issued.jti, input.email, String(REFRESH_TTL_DAYS), issued.jti]);
    return { ...body, token: signToken({ email: input.email, ver }), refreshToken: issued.token };
  } },

  { method: 'get', path: '/users', action: 'LIST_USERS', tokenIdentity: 'actor', fields: [
    { name: 'limit', pattern: INT, required: false },
    { name: 'offset', pattern: INT, required: false },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'get', path: '/users/:email', action: 'GET_USER', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'get', path: '/wallet/balance', action: 'CHECK_BALANCE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/wallet/transfer', action: 'TRANSFER', tokenIdentity: 'from', fields: [
    { name: 'from', pattern: EMAIL, required: true },
    { name: 'to', pattern: EMAIL, required: true },
    { name: 'amount', pattern: AMOUNT, required: true },
    { name: 'idempotencyKey', pattern: KEY, required: false },
  ] },
  { method: 'get', path: '/profile', action: 'GET_DASHBOARD', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/profile/email/request', action: 'REQ_EMAIL_CHANGE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'newEmail', pattern: EMAIL, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ], onSuccess: async (body, input, { mailer }) => {
    await mailer.sendVerification({ to: input.newEmail, purpose: 'EMAIL_CHANGE', code: body.data[1] });
    return { data: ['CODE_SENT'] };
  } },
  { method: 'post', path: '/profile/email/confirm', action: 'CONFIRM_EMAIL_CHANGE', tokenIdentity: 'actor', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'newEmail', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
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
];

async function tokenVersion(email) {
  try {
    const raw = await invoke('GET_TOKEN_VERSION', [email]);
    const v = Number(String(raw).split('|')[1]);
    return Number.isFinite(v) ? v : 1;
  } catch {
    return 1;
  }
}

// The access token carries the user's token version; a mismatch means the token
// (or all tokens) was revoked since it was issued.
async function requireActiveToken(req, res, next) {
  try {
    const email = (req.user && req.user.email) || '';
    const ver = String((req.user && req.user.ver) ?? '');
    const raw = await invoke('CHECK_TOKEN', [email, ver]);
    if (raw === 'SUCCESS|TOKEN_VALID') return next();
    return res.status(401).json({ error: 'TOKEN_REVOKED' });
  } catch (err) {
    return next(err);
  }
}

export function buildRouter({ mailer } = {}) {
  const router = express.Router();
  const authLimiter = rateLimiter();
  const apiLimiter = apiRateLimiter();

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
  router.get('/metrics', apiLimiter, requireAuth, requireActiveToken, (_req, res) => {
    res.type('text/plain').send(metricsText());
  });

  // Pure transport: exchange a refresh token for a new access token. The old
  // refresh token is checked against the session store and rotated (revoked).
  router.post('/auth/refresh', authLimiter, async (req, res) => {
    try {
      const payload = verifyRefresh((req.body && req.body.refreshToken) || '');
      const check = await invoke('CHECK_SESSION', [payload.jti || '']);
      if (check !== 'SUCCESS|SESSION_VALID') {
        return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
      }
      await invoke('REVOKE_SESSION', [payload.jti || '']);
      const family = payload.family || payload.jti;
      const ver = await tokenVersion(payload.email);
      const issued = signRefresh({ email: payload.email, family });
      await invoke('STORE_SESSION', [issued.jti, payload.email, String(REFRESH_TTL_DAYS), family]);
      return res.json({
        data: ['REFRESHED'],
        token: signToken({ email: payload.email, ver }),
        refreshToken: issued.token,
      });
    } catch {
      return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
    }
  });

  // Revoke the presented refresh token (logout).
  router.post('/auth/logout', authLimiter, async (req, res) => {
    try {
      const payload = verifyRefresh((req.body && req.body.refreshToken) || '');
      await invoke('REVOKE_SESSION', [payload.jti || '']);
      // Revoke the access tokens too, not just this refresh token.
      await invoke('REVOKE_TOKENS', [payload.email || '']);
      return res.json({ data: ['LOGGED_OUT'] });
    } catch {
      return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
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
        const params = buildParams(route, input);
        assertLineLength(route.action, params);
        const t0 = Date.now();
        const raw = await invoke(route.action, params);
        res.set('X-Cobol-Ms', String(Date.now() - t0));
        const { status, body } = toHttp(raw);
        if (status === 200 && route.onSuccess) {
          return res.status(status).json(await route.onSuccess(body, input, { mailer }));
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

export function buildApp({ logger = null, mailer = null } = {}) {
  const app = express();
  app.use(helmet());
  app.use(createRequestObserver({ logger }));
  app.use(express.json());
  app.use(buildRouter({ mailer: mailer || createMailer({ logger }) }));
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
