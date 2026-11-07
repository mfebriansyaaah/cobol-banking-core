import express from 'express';
import helmet from 'helmet';
import { randomUUID } from 'node:crypto';
import { invoke, InvocationTimeout, InvocationError, PoolSaturated } from './invoker.js';
import { toHttp } from './result.js';
import { buildParams, ValidationError, assertLineLength } from './validation.js';
import { ALL_ROUTES } from './routes/index.js';
import { groupRoutes } from './mount.js';
import {
  requireAuth,
  signToken,
  signRefresh,
  verifyRefresh,
  verifyAccess,
  verifyStepUp,
  REFRESH_TTL_DAYS,
  ACCESS_TTL_SECONDS,
} from './auth.js';
import { rateLimiter, apiRateLimiter } from './rateLimit.js';
import { createRequestObserver, metricsText, recordError, recordAuthFailure } from './observability.js';
import { getPool } from './pool.js';
import { createMailer } from './mailer.js';
import { assertPasswordAllowed } from './integrations/security/pwned.js';
import { verifyTurnstile } from './integrations/bot/turnstile.js';
import { createTokenStore } from './tokenStore.js';
import { RESPONSE_MAPPERS, sanitizeMeta, tokenVersion } from './responseMappers.js';

// Reasons counted in gateway_auth_failures_total. Telemetry only: the code
// still decides, this list only decides which failures are worth counting as
// authentication events.
const AUTH_FAILURE_CODES = new Set([
  'INVALID_CREDENTIALS',
  'INVALID_MFA',
  'MFA_REQUIRED',
  'MFA_SETUP_REQUIRED',
  'ACCOUNT_LOCKED',
  'USER_SUSPENDED',
  'USER_CLOSED',
  'UNVERIFIED',
  'SESSION_NOT_FOUND',
  'SESSION_EXPIRED',
  'SESSION_FAMILY_EXPIRED',
  'SESSION_REUSED',
  'TOKEN_REVOKED',
  'PERMISSION_DENIED',
  'FORBIDDEN',
  'ROLE_DENIED',
]);

// Each route maps an HTTP endpoint to a COBOL action. `fields` lists the
// parameters in the exact order the COBOL module expects them. `tokenIdentity`
// names the field filled from the verified token, never from the request body.
export const ROUTES = [...ALL_ROUTES];

// Response mappers and helpers live in responseMappers.js.
// The access token carries the user's token version and its own jti; a mismatch
// (or a denylisted jti) means it was revoked since it was issued.
export function buildRouter({ mailer, tokenStore } = {}) {
  const STRING_TYPE = 'string';
  const router = express.Router();
  const authLimiter = rateLimiter({ failOpen: false });
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

  // Permission gate for operator-only endpoints (checked live in COBOL).
  // CHECK_PERMISSION answers whether the actor holds the permission, so a
  // future grant to another role needs no gateway change.
  const requirePermission = (permission) => async (req, res, next) => {
    try {
      const email = (req.user && req.user.email) || '';
      const raw = await invoke('CHECK_PERMISSION', [email, permission]);
      if (raw === 'SUCCESS|PERMISSION_OK') return next();
      if (raw === 'ERROR|ACCOUNT_NOT_FOUND') return res.status(404).json({ error: 'ACCOUNT_NOT_FOUND' });
      recordAuthFailure('PERMISSION_DENIED');
      return res.status(403).json({ error: 'FORBIDDEN' });
    } catch (err) {
      return next(err);
    }
  };

  // Verify a fresh, short-lived step-up proof (from POST /auth/step-up) bound
  // to this caller and its token version. Returns true when it is valid;
  // otherwise it has already written the 401.
  const stepUpProofValid = (req, res) => {
    const token = req.get('x-step-up') || (req.body && req.body.stepUpToken) || '';
    if (!token) {
      recordAuthFailure('STEP_UP_REQUIRED');
      res.status(401).json({ error: 'STEP_UP_REQUIRED' });
      return false;
    }
    let payload;
    try {
      payload = verifyStepUp(token);
    } catch {
      res.status(401).json({ error: 'STEP_UP_REQUIRED' });
      return false;
    }
    const u = req.user || {};
    if (payload.email !== u.email || String(payload.ver) !== String(u.ver)) {
      res.status(401).json({ error: 'STEP_UP_REQUIRED' });
      return false;
    }
    return true;
  };

  // Static gate for privileged admin writes (always required).
  const requireStepUp = (req, res, next) => {
    if (!stepUpProofValid(req, res)) return undefined;
    return next();
  };

  // Risk-based gate for customer actions: COBOL's STEP_UP_REQUIRED reads the
  // owner-controlled policy and decides; the gateway only enforces the answer.
  const requireStepUpPolicy = (action) => async (req, res, next) => {
    try {
      const email = (req.user && req.user.email) || '';
      const amount = (req.body && req.body.amount) ?? (req.query && req.query.amount) ?? '';
      const raw = await invoke('STEP_UP_REQUIRED', [email, action, String(amount)]);
      if (raw === 'SUCCESS|STEP_UP_REQUIRED') {
        if (!stepUpProofValid(req, res)) return undefined;
        return next();
      }
      if (raw.startsWith('ERROR')) {
        recordAuthFailure('STEP_UP_POLICY_FAILED');
        return res.status(500).json({ error: 'STEP_UP_POLICY_FAILED' });
      }
      return next();
    } catch (err) {
      return next(err);
    }
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
  router.get('/metrics', apiLimiter, requireAuth, requireActiveToken, requirePermission('AUDIT_READ'), (_req, res) => {
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
      try {
        await invoke('LOGIN_NOTICE', [payload.email, ua, ip]);
      } catch {
        /* best effort */
      }
      const enroll = (await invoke('MFA_ENROLL_REQUIRED', [payload.email])) === 'SUCCESS|1';
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

  const registerRoute = (target, route) => {
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
        // Breached-password gate (PR-093): routes carrying a *new* password
        // opt in via `passwordField`. Breached -> 400, API down -> fail open
        // with a metric (rate limits still apply).
        const pwField = route.passwordField;
        const candidate = pwField ? input[pwField] : '';
        if (typeof candidate === STRING_TYPE && candidate) {
          const allowed = await assertPasswordAllowed(candidate);
          if (!allowed) {
            res.locals.errorCode = 'BREACHED_PASSWORD';
            recordError('BREACHED_PASSWORD');
            return res.status(400).json({ error: 'BREACHED_PASSWORD' });
          }
        }
        // Bot gate (PR-094): routes opt in via `captcha: true`; the token
        // arrives as `captchaToken` and never reaches COBOL. Missing/invalid
        // rejects; provider down fails open (rate limiters still apply).
        if (route.captcha) {
          const verdict = await verifyTurnstile(input.captchaToken, { remoteip: req.ip });
          if (!verdict.ok) {
            const code = verdict.code === 'missing-input-response' ? 'CAPTCHA_REQUIRED' : 'CAPTCHA_REJECTED';
            res.locals.errorCode = code;
            recordError(code);
            return res.status(400).json({ error: code });
          }
        }
        const t0 = Date.now();
        const raw = await invoke(route.action, params);
        res.set('X-Cobol-Ms', String(Date.now() - t0));
        const { status, body } = toHttp(raw);
        if (status !== 200 && body && body.error) {
          res.locals.errorCode = body.error;
          recordError(body.error);
          if (AUTH_FAILURE_CODES.has(body.error)) recordAuthFailure(body.error);
        }
        const mapper = status === 200 ? RESPONSE_MAPPERS[route.action] : null;
        if (mapper) {
          return res.status(status).json(await mapper(body, input, { mailer, req }));
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
    else if (route.stepUpPolicy) chain.push(requireStepUpPolicy(route.stepUpPolicy));
    chain.push(handler);
    target[route.method](route.path, ...chain);
  };

  // Domain mounts (PR-054): one sub-router per first path segment, mounted
  // at '/' in first-seen order. Matching is identical to the flat table
  // (see routes/mount.js); the split only bounds blast radius per domain.
  for (const { routes } of groupRoutes(ROUTES)) {
    const sub = express.Router();
    for (const route of routes) registerRoute(sub, route);
    router.use(sub);
  }

  return router;
}

// Advisory misconfiguration check for the rate-limit key: TRUST_PROXY=true
// trusts any X-Forwarded-For header and lets callers spoof their key (the
// limiter is bypassed). An unset value is sound: loopback-only trust keeps a
// directly exposed socket on its real peer IP. Returns a warning message, or
// null when the setting looks sound.
export function trustProxyWarning() {
  const v = process.env.TRUST_PROXY;
  if (v === 'true') {
    return 'TRUST_PROXY=true trusts any X-Forwarded-For header, letting callers spoof the rate-limit key (use a hop count or subnet instead)';
  }
  return null;
}

export function buildApp({ logger = null, mailer = null, tokenStore = null } = {}) {
  const app = express();
  // Behind a proxy the client IP (and so the rate-limit key) must come from the
  // forwarded headers. Loopback-only unless configured: a same-host proxy is
  // trusted, a remote X-Forwarded-For is not (spoof-proof), and a directly
  // exposed socket keeps its real peer IP. Set TRUST_PROXY to the hop count
  // when the proxy lives on another host.
  app.set('trust proxy', process.env.TRUST_PROXY || 'loopback');
  app.use(helmet());
  app.use(createRequestObserver({ logger }));
  // Legitimate bodies are under a kilobyte (short credential/profile fields);
  // reject anything larger before it costs parsing memory or reaches COBOL.
  app.use(express.json({ limit: process.env.JSON_BODY_LIMIT || '20kb' }));
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
    } else if (err instanceof PoolSaturated) {
      status = 503;
      code = 'POOL_SATURATED';
    } else if (err instanceof InvocationError) {
      status = 502;
      code = 'COBOL_UNAVAILABLE';
    } else if (err.status === 413 || err.type === 'entity.too.large') {
      status = 413;
      code = 'BODY_TOO_LARGE';
    }
    res.locals.errorCode = code;
    recordError(code);
    // Fail-open forensics: tests build the app without a logger, so an
    // unmapped 500 would otherwise leave only {"error":"INTERNAL"} with no
    // cause. stderr never touches the HTTP body or the COBOL pipe. The URL
    // is never logged raw (paths/queries may carry emails or tokens): log
    // the matched route template instead, like the request observer does.
    const record = {
      ts: new Date().toISOString(),
      level: 'error',
      event: 'gateway_error',
      code,
      status,
      method: _req && _req.method,
      route: (_req && _req.route && _req.route.path) || 'unmatched',
      message: err && err.message,
      stack: err && err.stack,
    };
    if (logger) {
      logger(record);
    } else {
      // stderr only: never touches the HTTP body or the COBOL pipe.
      process.stderr.write(JSON.stringify(record) + '\n');
    }
    if (err instanceof ValidationError) {
      return res.status(status).json({ error: code, field: err.field });
    }
    return res.status(status).json({ error: code });
  });
  return app;
}
