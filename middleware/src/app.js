import express from 'express';
import { invoke, InvocationTimeout, InvocationError } from './invoker.js';
import { toHttp } from './result.js';
import { buildParams, ValidationError, PATTERNS } from './validation.js';
import { requireAuth, signToken } from './auth.js';

const { EMAIL, PASSWORD, NAME, DATE, CODE, ROLE, AMOUNT } = PATTERNS;

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
  ], onSuccess: (body, input) => ({ ...body, token: signToken({ email: input.email }) }) },

  { method: 'get', path: '/users', action: 'LIST_USERS', fields: [] },
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
  { method: 'post', path: '/admin/role', action: 'CHANGE_ROLE', fields: [
    { name: 'email', pattern: EMAIL, required: true },
    { name: 'role', pattern: ROLE, required: true },
    { name: 'actor', pattern: EMAIL, required: true },
  ] },
];

export function buildRouter() {
  const router = express.Router();

  router.get('/health', (_req, res) => res.json({ data: ['OK'] }));

  for (const route of ROUTES) {
    const handler = async (req, res, next) => {
      try {
        const input = { ...req.params, ...req.query, ...req.body };
        const params = buildParams(route, input);
        const raw = await invoke(route.action, params);
        const { status, body } = toHttp(raw);
        if (status === 200 && route.onSuccess) {
          return res.status(status).json(route.onSuccess(body, input));
        }
        return res.status(status).json(body);
      } catch (err) {
        return next(err);
      }
    };
    const chain = route.public ? [handler] : [requireAuth, handler];
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
