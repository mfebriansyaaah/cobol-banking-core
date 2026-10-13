// Support-only observability: per-request structured logging and in-process
// metrics. It counts and describes traffic; it makes no business decisions.
import { randomUUID } from 'node:crypto';
import { performance } from 'node:perf_hooks';

// --- Metrics registry (process-wide counters) ----------------------------
const metrics = {
  total: 0,
  byRoute: new Map(), // key: `${method}|${route}|${status}` -> count
};

export function resetMetrics() {
  metrics.total = 0;
  metrics.byRoute.clear();
}

function escapeLabel(value) {
  return String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
}

export function recordRequest({ method, route, status }) {
  metrics.total += 1;
  const key = `${method}|${route || 'unknown'}|${status}`;
  metrics.byRoute.set(key, (metrics.byRoute.get(key) || 0) + 1);
}

/** Prometheus text exposition of the counters. */
export function metricsText() {
  const lines = [
    '# HELP gateway_requests_total Total HTTP requests handled.',
    '# TYPE gateway_requests_total counter',
  ];
  if (metrics.total === 0) {
    lines.push('gateway_requests_total 0');
  } else {
    for (const [key, count] of metrics.byRoute) {
      const [method, route, status] = key.split('|');
      lines.push(
        `gateway_requests_total{method="${escapeLabel(method)}",route="${escapeLabel(route)}",status="${escapeLabel(status)}"} ${count}`,
      );
    }
  }
  return `${lines.join('\n')}\n`;
}

// --- Request logging -----------------------------------------------------
const jsonLogger = (line) => process.stdout.write(`${JSON.stringify(line)}\n`);

export function createRequestObserver({ logger = null } = {}) {
  return function observe(req, res, next) {
    const id = req.get('x-request-id') || randomUUID();
    res.set('X-Request-Id', id);
    const start = performance.now();

    res.on('finish', () => {
      const route = (req.route && `${req.baseUrl || ''}${req.route.path || ''}`) || req.path;
      const durationMs = Math.round(performance.now() - start);
      recordRequest({ method: req.method, route, status: res.statusCode });
      if (logger) {
        const cobolHeader = res.getHeader('X-Cobol-Ms');
        logger({
          ts: new Date().toISOString(),
          level: 'info',
          event: 'http_request',
          id,
          method: req.method,
          route,
          status: res.statusCode,
          durationMs,
          cobolMs: cobolHeader === undefined ? null : Number(cobolHeader),
        });
      }
    });

    return next();
  };
}

export { jsonLogger };
