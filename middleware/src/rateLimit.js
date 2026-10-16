// Fixed-window rate limiter. Support-only security: it counts requests, it does
// not touch business logic. Counters live in a pluggable store so several
// gateway instances can share them (Redis); the default store is in-memory.
import { incCounter } from './observability.js';

/** In-process fixed-window counter. */
export function memoryStore() {
  const hits = new Map();
  return {
    async hit(key, windowMs) {
      const now = Date.now();
      let rec = hits.get(key);
      if (!rec || now > rec.reset) {
        rec = { count: 0, reset: now + windowMs };
        hits.set(key, rec);
      }
      rec.count += 1;
      return { count: rec.count, resetAt: rec.reset };
    },
  };
}

/** Redis-backed counter (node-redis), loaded only when REDIS_URL is set. */
export function redisStore() {
  let clientPromise;
  function client() {
    if (!clientPromise) {
      clientPromise = import('redis').then(async ({ createClient }) => {
        const c = createClient({ url: process.env.REDIS_URL });
        c.on('error', () => {}); // never crash the gateway on a store blip
        await c.connect();
        return c;
      });
    }
    return clientPromise;
  }
  return {
    async hit(key, windowMs) {
      const c = await client();
      const k = `ratelimit:${key}`;
      const count = await c.incr(k);
      if (count === 1) await c.pExpire(k, windowMs);
      const ttl = await c.pTTL(k);
      return { count, resetAt: Date.now() + (ttl > 0 ? ttl : windowMs) };
    },
  };
}

export function storeFromEnv() {
  return process.env.REDIS_URL ? redisStore() : memoryStore();
}

/**
 * Build a limiter middleware over a store. If the store fails, the request is
 * allowed (fail-open): a broken counter must not take the API down. The event
 * is counted (`gateway_ratelimit_failopen_total`, exported via /metrics and
 * the push exporter) so a dead store — and the absent brute-force protection
 * — is visible instead of silent. Deliberately counter-only: logging every
 * request during an outage would flood the logs.
 */
export function createRateLimiter({ store, windowMs = 15 * 60 * 1000, max = 100 }) {
  return async function limit(req, res, next) {
    const now = Date.now();
    let result;
    try {
      result = await store.hit(req.ip || 'unknown', windowMs);
    } catch {
      incCounter('gateway_ratelimit_failopen_total');
      return next();
    }
    if (result.count > max) {
      res.set('Retry-After', String(Math.ceil((result.resetAt - now) / 1000)));
      return res.status(429).json({ error: 'RATE_LIMITED' });
    }
    return next();
  };
}

export function rateLimiter(opts = {}) {
  const windowMs = Number(opts.windowMs ?? process.env.RATE_LIMIT_WINDOW_MS ?? 15 * 60 * 1000);
  const max = Number(opts.max ?? process.env.RATE_LIMIT_MAX ?? 100);
  return createRateLimiter({ store: opts.store ?? storeFromEnv(), windowMs, max });
}

// General API limiter for non-auth routes. It is deliberately more generous
// than the auth limiter (which guards credential guessing); admin and read
// endpoints still get a per-client ceiling.
export function apiRateLimiter() {
  return createRateLimiter({
    store: storeFromEnv(),
    windowMs: Number(process.env.API_RATE_LIMIT_WINDOW_MS ?? 15 * 60 * 1000),
    max: Number(process.env.API_RATE_LIMIT_MAX ?? 600),
  });
}
