import express from 'express';
import { invoke, InvocationTimeout, InvocationError } from './invoker.js';
import { toHttp } from './result.js';
import { buildParams, ValidationError, PATTERNS, assertLineLength } from './validation.js';
import { requireAuth, signToken, signRefresh, verifyRefresh, REFRESH_TTL_DAYS } from './auth.js';
import { rateLimiter } from './rateLimit.js';

const { EMAIL, PASSWORD, NAME, DATE, CODE, ROLE, AMOUNT, INT, KEY } = PATTERNS;

// Each route maps an HTTP endpoint to a COBOL action. `fields` lists the
// parameters in the exact order the COBOL module expects them.
const ROUTES = [
  { method: 'post', path: '/auth/signup', action: 'REQUEST_SIGNUP', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
    { name: 'name', pattern: NAME, required: true },
    { name: 'dob', pattern: DATE, required: true },
  ] },
  { method: 'post', path: '/auth/verify', action: 'VERIFY_EMAIL', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
  ] },
  { method: 'post', path: '/auth/login', action: 'AUTH_LOGIN', public: true, fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'password', pattern: PASSWORD, required: true },
  ], onSuccess: async (body, input) => {
    const issued = signRefresh({ email: input.email });
    await invoke('STORE_SESSION', [issued.jti, input.email, String(REFRESH_TTL_DAYS)]);
    return { ...body, token: signToken({ email: input.email }), refreshToken: issued.token };
  } },

  { method: 'get', path: '/users', action: 'LIST_USERS', fields: [
    { name: 'limit', pattern: INT, required: false },
    { name: 'offset', pattern: INT, required: false },
  ] },
  { method: 'get', path: '/users/:email', action: 'GET_USER', fields: [
    { name: 'email', pattern: EMAIL, required: true },
  ] },
  { method: 'get', path: '/wallet/balance', action: 'CHECK_BALANCE', fields: [
    { name: 'email', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/wallet/transfer', action: 'TRANSFER', fields: [
    { name: 'from', pattern: EMAIL, required: true },
    { name: 'to', pattern: EMAIL, required: true },
    { name: 'amount', pattern: AMOUNT, required: true },
    { name: 'idempotencyKey', pattern: KEY, required: false },
  ] },
  { method: 'get', path: '/profile', action: 'GET_DASHBOARD', fields: [
    { name: 'email', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/profile/email/request', action: 'REQ_EMAIL_CHANGE', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'newEmail', pattern: EMAIL, required: true },
  ] },
  { method: 'post', path: '/profile/email/confirm', action: 'CONFIRM_EMAIL_CHANGE', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'newEmail', pattern: EMAIL, required: true },
    { name: 'code', pattern: CODE, required: true },
  ] },
  { method: 'get', path: '/admin/role', action: 'CHECK_ROLE', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'role', pattern: ROLE, required: true },
  ] },
  // Read-only consistency check: every account balance against its ledger sum.
  { method: 'get', path: '/admin/reconcile', action: 'RECONCILE', fields: [] },
  { method: 'post', path: '/admin/role', action: 'CHANGE_ROLE', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'role', pattern: ROLE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
];

export function buildRouter() {
  const router = express.Router();
  const authLimiter = rateLimiter();

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
      const issued = signRefresh({ email: payload.email });
      await invoke('STORE_SESSION', [issued.jti, payload.email, String(REFRESH_TTL_DAYS)]);
      return res.json({
        data: ['REFRESHED'],
        token: signToken({ email: payload.email }),
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
        const params = buildParams(route, input);
        assertLineLength(route.action, params);
        const t0 = Date.now();
        const raw = await invoke(route.action, params);
        res.set('X-Cobol-Ms', String(Date.now() - t0));
        const { status, body } = toHttp(raw);
        if (status === 200 && route.onSuccess) {
          return res.status(status).json(await route.onSuccess(body, input));
        }
        return res.status(status).json(body);
      } catch (err) {
        return next(err);
      }
    };
    const chain = [];
    if (route.path.startsWith('/auth')) chain.push(authLimiter);
    if (!route.public) chain.push(requireAuth);
    chain.push(handler);
    router[route.method](route.path, ...chain);
  }

  return router;
}

export function buildApp() {
  const app = express();
  app.use(express.json());
  app.use(buildRouter());
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
