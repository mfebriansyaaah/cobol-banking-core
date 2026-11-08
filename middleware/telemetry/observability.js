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
  authFailures: new Map(), // key: authentication failure reason -> count
  counters: new Map(), // name -> count
  histograms: new Map(), // name -> { buckets: number[], sum, count }
  gauges: new Map(), // name -> value
};

export function resetMetrics() {
  metrics.total = 0;
  metrics.byRoute.clear();
  metrics.byError.clear();
  metrics.authFailures.clear();
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

/** Count an authentication failure by reason (telemetry only). */
export function recordAuthFailure(reason) {
  if (!reason) return;
  metrics.authFailures.set(reason, (metrics.authFailures.get(reason) || 0) + 1);
}

/** Count a failed request by its error code (business or transport). */
export function recordError(code) {
  if (!code) return;
  metrics.byError.set(code, (metrics.byError.get(code) || 0) + 1);
}

/** Prometheus metric name validation (ADR-0006): base without labels. */
function metricBase(name) {
  const idx = String(name).indexOf('{');
  return idx === -1 ? String(name) : String(name).slice(0, idx);
}

/** Prometheus text exposition of the counters (valid exposition format). */
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
  const seenGauge = new Set();
  for (const [name, value] of metrics.gauges) {
    const base = metricBase(name);
    if (!seenGauge.has(base)) {
      lines.push(`# TYPE ${base} gauge`);
      seenGauge.add(base);
    }
    lines.push(`${name} ${value}`);
  }
  const seenCounter = new Set();
  for (const [name, value] of metrics.counters) {
    const base = metricBase(name);
    if (!seenCounter.has(base)) {
      lines.push(`# TYPE ${base} counter`);
      seenCounter.add(base);
    }
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
  if (metrics.authFailures.size > 0) {
    lines.push('# HELP gateway_auth_failures_total Authentication failures by reason.');
    lines.push('# TYPE gateway_auth_failures_total counter');
    for (const [reason, count] of metrics.authFailures) {
      lines.push(`gateway_auth_failures_total{reason="${escapeLabel(reason)}"} ${count}`);
    }
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

// A caller-supplied correlation id is only echoed when it is well formed: a
// bounded length and a safe charset, so it cannot inject into logs or bloat
// them. Anything else is replaced with a freshly minted UUID.
const REQUEST_ID_RE = /^[A-Za-z0-9._-]{1,64}$/;

function requestIdFor(req) {
  const raw = req.get('x-request-id');
  return raw && REQUEST_ID_RE.test(raw) ? raw : randomUUID();
}

export function createRequestObserver({ logger = null } = {}) {
  return function observe(req, res, next) {
    const id = requestIdFor(req);
    // Stash the id on the request so downstream handlers and the error
    // middleware can include it: without this the id exists only in the
    // response header and the http_request line and cannot join anything.
    req.requestId = id;
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

export async function pushMetrics(url, logger = null, timeoutMs = 5000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'text/plain; version=0.0.4' },
      body: metricsText(),
      signal: controller.signal,
    });
    if (!res.ok && logger) {
      logger({ ts: new Date().toISOString(), level: 'warn', event: 'metrics_push_failed', status: res.status });
    }
    return res.status;
  } finally {
    clearTimeout(timer);
  }
}

export function startMetricsExporter({ url, intervalMs = 15000, logger = null } = {}) {
  if (!url) return () => {};
  let inFlight = false;
  const timer = setInterval(async () => {
    // Skip if the previous push is still running (a slow/hung collector must
    // not pile up overlapping requests).
    if (inFlight) return;
    inFlight = true;
    try {
      await pushMetrics(url, logger);
    } catch (err) {
      if (logger) logger({ ts: new Date().toISOString(), level: 'warn', event: 'metrics_push_error', message: err && err.message });
    } finally {
      inFlight = false;
    }
  }, intervalMs);
  if (timer.unref) timer.unref();
  return () => clearInterval(timer);
}

