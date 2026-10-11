// Fixed-window rate limiter (in-memory). Support-only security: it counts
// requests, it does not touch business logic.

export function rateLimiter(opts = {}) {
  const windowMs = Number(opts.windowMs ?? process.env.RATE_LIMIT_WINDOW_MS ?? 15 * 60 * 1000);
  const max = Number(opts.max ?? process.env.RATE_LIMIT_MAX ?? 100);
  const hits = new Map();

  return function limit(req, res, next) {
    const now = Date.now();
    const key = req.ip || 'unknown';
    let rec = hits.get(key);
    if (!rec || now > rec.reset) {
      rec = { count: 0, reset: now + windowMs };
      hits.set(key, rec);
    }
    rec.count += 1;
    if (rec.count > max) {
      res.set('Retry-After', String(Math.ceil((rec.reset - now) / 1000)));
      return res.status(429).json({ error: 'RATE_LIMITED' });
    }
    return next();
  };
}
