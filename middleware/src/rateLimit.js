// Fixed-window rate limiter. Support-only security: it counts requests, it does
// not touch business logic. Counters live in a pluggable store so several
// gateway instances can share them (Redis); the default store is in-memory.
import { incCounter } from '../telemetry/observability.js';

/**
 * In-process fixed-window counter. The map is bounded: an attacker can mint
 * arbitrary client keys (one per forged source address), so an unbounded map
 * would turn every request into an O(n) sweep and eventually exhaust memory.
 * Expired entries are swept periodically; when the cap is reached, expired
 * entries are removed first and the oldest live keys are evicted.
 */
export function memoryStore({ maxKeys = Number(process.env.RATE_LIMIT_MAX_KEYS || 10000) } = {}) {
  const cap = Number.isFinite(maxKeys) && maxKeys > 0 ? Math.floor(maxKeys) : 10000;
  const hits = new Map();
  let nextSweep = 0;
  const SWEEP_MS = 60_000;

  function sweep(now, force = false) {
    if (!force && now < nextSweep) return;
    for (const [k, rec] of hits) {
      if (now > rec.reset) hits.delete(k);
    }
    nextSweep = now + SWEEP_MS;
  }

  function enforceCap(now) {
    if (hits.size < cap) return;
    // Expired entries are the cheapest eviction; only then remove the oldest
    // live keys (Map insertion order is the age order here).
    sweep(now, true);
    while (hits.size >= cap) {
      const oldest = hits.keys().next().value;
      if (oldest === undefined) break;
      hits.delete(oldest);
    }
  }

  return {
    get size() {
      return hits.size;
    },
    stats() {
      return { size: hits.size, maxKeys: cap };
    },
    async hit(key, windowMs) {
      const now = Date.now();
      sweep(now);
      let rec = hits.get(key);
      if (!rec || now > rec.reset) {
        enforceCap(now);
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

/** Fail closed in production if the bounded in-memory fallback is misconfigured. */
export function assertRateLimitConfig() {
  const raw = process.env.RATE_LIMIT_MAX_KEYS;
  if (raw === undefined || String(raw).trim() === '') return;
  if (!/^\d+$/.test(String(raw).trim()) || Number(raw) < 1) {
    throw new Error(`RATE_LIMIT_MAX_KEYS must be a positive whole number, got "${raw}"`);
  }
}

/**
 * Build a limiter middleware over a store. If the store fails, the request is
 * allowed (fail-open): a broken counter must not take the API down. The event
 * is counted (`gateway_ratelimit_failopen_total`, exported via /metrics and
 * the push exporter) so a dead store — and the absent brute-force protection
 * — is visible instead of silent. Deliberately counter-only: logging every
 * request during an outage would flood the logs.
 */
export function createRateLimiter({ store, windowMs = 15 * 60 * 1000, max = 100, failOpen = true }) {
  return async function limit(req, res, next) {
    const now = Date.now();
    let result;
    try {
      result = await store.hit(req.ip || 'unknown', windowMs);
    } catch {
      incCounter('gateway_ratelimit_failopen_total');
      if (failOpen) return next();
      return res.status(503).json({ error: 'RATE_LIMIT_STORE_UNAVAILABLE' });
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
  const failOpen = opts.failOpen ?? process.env.RATE_LIMIT_FAIL_OPEN !== 'false';
  return createRateLimiter({ store: opts.store ?? storeFromEnv(), windowMs, max, failOpen });
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
