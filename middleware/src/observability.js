// Support-only observability: per-request structured logging and in-process
// metrics. It counts and describes traffic; it makes no business decisions.
import { randomUUID } from 'node:crypto';
import { performance } from 'node:perf_hooks';

// --- Metrics registry (process-wide counters and gauges) ------------------
const BUCKETS_MS = [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000];

const metrics = {
  total: 0,
  byRoute: new Map(), // key: `${method}|${route}|${status}` -> count
  byError: new Map(), // key: error code -> count
  counters: new Map(), // name -> count
  histograms: new Map(), // name -> { buckets: number[], sum, count }
  gauges: new Map(), // name -> value
};

export function resetMetrics() {
  metrics.total = 0;
  metrics.byRoute.clear();
  metrics.byError.clear();
  metrics.counters.clear();
  metrics.histograms.clear();
  metrics.gauges.clear();
}

/** Set a gauge (e.g. worker-pool size). Rendered by metricsText. */
export function setGauge(name, value) {
  metrics.gauges.set(name, Number(value) || 0);
}

function escapeLabel(value) {
  return String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
}

export function recordRequest({ method, route, status, durationMs, cobolMs }) {
  metrics.total += 1;
  const key = `${method}|${route || 'unknown'}|${status}`;
  metrics.byRoute.set(key, (metrics.byRoute.get(key) || 0) + 1);
  if (Number.isFinite(durationMs)) observeHistogram('gateway_request_duration_ms', durationMs);
  if (Number.isFinite(cobolMs)) observeHistogram('gateway_cobol_duration_ms', cobolMs);
}

/** Increment a named counter (rendered as `<name> <value>`). */
export function incCounter(name, by = 1) {
  if (!name) return;
  metrics.counters.set(name, (metrics.counters.get(name) || 0) + by);
}

/** Observe a value into a fixed-bucket histogram (ms). */
export function observeHistogram(name, value) {
  let h = metrics.histograms.get(name);
  if (!h) {
    h = { buckets: BUCKETS_MS.map(() => 0), sum: 0, count: 0 };
    metrics.histograms.set(name, h);
  }
  h.sum += value;
  h.count += 1;
  for (let i = 0; i < BUCKETS_MS.length; i += 1) {
    if (value <= BUCKETS_MS[i]) h.buckets[i] += 1;
  }
}

/** Count a failed request by its error code (business or transport). */
export function recordError(code) {
  if (!code) return;
  metrics.byError.set(code, (metrics.byError.get(code) || 0) + 1);
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
  for (const [name, value] of metrics.gauges) {
    lines.push(`# TYPE ${name} gauge`);
    lines.push(`${name} ${value}`);
  }
  for (const [name, value] of metrics.counters) {
    lines.push(`# TYPE ${name} counter`);
    lines.push(`${name} ${value}`);
  }
  for (const [name, h] of metrics.histograms) {
    lines.push(`# TYPE ${name} histogram`);
    for (let i = 0; i < BUCKETS_MS.length; i += 1) {
      lines.push(`${name}_bucket{le="${BUCKETS_MS[i]}"} ${h.buckets[i]}`);
    }
    lines.push(`${name}_bucket{le="+Inf"} ${h.count}`);
    lines.push(`${name}_sum ${h.sum}`);
    lines.push(`${name}_count ${h.count}`);
  }
  if (metrics.byError.size > 0) {
    lines.push('# HELP gateway_errors_total Failed requests by error code.');
    lines.push('# TYPE gateway_errors_total counter');
    for (const [code, count] of metrics.byError) {
      lines.push(`gateway_errors_total{code="${escapeLabel(code)}"} ${count}`);
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
      // Matched routes use their template; unmatched requests collapse to a
      // constant so a raw path (which may carry an email/PII) never becomes a
      // high-cardinality metric or log label.
      const route = (req.route && `${req.baseUrl || ''}${req.route.path || ''}`) || 'unmatched';
      const durationMs = Math.round(performance.now() - start);
      const cobolHeader = res.getHeader('X-Cobol-Ms');
      const cobolMs = cobolHeader === undefined ? null : Number(cobolHeader);
      recordRequest({ method: req.method, route, status: res.statusCode, durationMs, cobolMs });
      if (logger) {
        logger({
          ts: new Date().toISOString(),
          level: res.statusCode >= 500 ? 'error' : 'info',
          event: 'http_request',
          id,
          method: req.method,
          route,
          status: res.statusCode,
          error: res.locals && res.locals.errorCode ? res.locals.errorCode : null,
          durationMs,
          cobolMs,
        });
      }
    });

    return next();
  };
}

export { jsonLogger };

// --- Push export ---------------------------------------------------------
// In-memory counters are exported (Prometheus text) to a remote collector
// (e.g. a Pushgateway or an OTLP-HTTP bridge) so they persist beyond the
// process and survive restarts on the collecting side.

export async function pushMetrics(url, logger = null) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'text/plain; version=0.0.4' },
    body: metricsText(),
  });
  if (!res.ok && logger) {
    logger({ ts: new Date().toISOString(), level: 'warn', event: 'metrics_push_failed', status: res.status });
  }
  return res.status;
}

export function startMetricsExporter({ url, intervalMs = 15000, logger = null } = {}) {
  if (!url) return () => {};
  const timer = setInterval(() => {
    pushMetrics(url, logger).catch(() => {
      if (logger) logger({ ts: new Date().toISOString(), level: 'warn', event: 'metrics_push_error' });
    });
  }, intervalMs);
  if (timer.unref) timer.unref();
  return () => clearInterval(timer);
}

