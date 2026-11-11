// Resilient HTTP for integrations (PR-086): timeouts, retry budgets,
// per-provider circuit breakers. Rules:
// - default timeout 3-5s (AbortSignal, no hanging sockets);
// - retry ONLY 429/5xx/network failures, never 4xx (no point) and never
//   after a send may have succeeded (no OTP double-send);
// - breaker opens after N consecutive failures, half-opens after cooldown;
// - every outcome is observable (state readable, transitions logged).
import { incCounter, observeHistogram, setGauge } from '../../telemetry/observability.js';

export const DEFAULT_TIMEOUT_MS = 4000;
export const DEFAULT_MAX_RETRIES = 2;
export const DEFAULT_BREAKER_THRESHOLD = 5;
export const DEFAULT_BREAKER_COOLDOWN_MS = 30000;

const breakers = new Map();

export function resetBreakers() {
  breakers.clear();
}

export function breakerState(provider) {
  const b = breakers.get(provider);
  if (!b) return { state: 'closed', failures: 0 };
  if (b.state === 'open' && Date.now() - b.openedAt >= b.cooldownMs) {
    b.state = 'half-open';
  }
  return { state: b.state, failures: b.failures };
}

function publishCircuitGauge(provider) {
  const b = breakers.get(provider);
  setGauge(`integration_circuit_open{provider="${provider}"}`, b && b.state === 'open' ? 1 : 0);
}

function recordSuccess(provider) {
  breakers.set(provider, {
    state: 'closed',
    failures: 0,
    openedAt: 0,
    cooldownMs: DEFAULT_BREAKER_COOLDOWN_MS,
  });
  publishCircuitGauge(provider);
}

function recordFailure(provider, threshold, cooldownMs) {
  const b = breakers.get(provider) || { failures: 0 };
  b.failures += 1;
  b.cooldownMs = cooldownMs;
  if (b.failures >= threshold) {
    b.state = 'open';
    b.openedAt = Date.now();
  } else {
    b.state = 'closed';
  }
  breakers.set(provider, b);
  publishCircuitGauge(provider);
  return b;
}

export function recordIntegration({ provider, result, durationMs }) {
  incCounter(`integration_requests_total{provider="${provider}",result="${result}"}`);
  if (Number.isFinite(durationMs)) observeHistogram('integration_request_duration_ms', durationMs);
}

export function recordFallback({ provider, reason }) {
  incCounter(`integration_fallback_total{provider="${provider}",reason="${reason}"}`);
}

export function isRetryable(err, res) {
  if (res) {
    if (res.status === 429) return true;
    if (res.status >= 500) return true;
    return false;
  }
  if (!err) return false;
  // Network-level failure (DNS, refused, reset, timeout): retryable.
  // Anything else (parse errors, validation, coding bugs): terminal.
  const code = err?.cause?.code ?? err?.code ?? '';
  return (
    err.name === 'TimeoutError' ||
    err.name === 'AbortError' ||
    ['ECONNREFUSED', 'ECONNRESET', 'ENOTFOUND', 'ETIMEDOUT', 'EAI_AGAIN'].includes(code)
  );
}

export async function resilientFetch(
  provider,
  url,
  options = {},
  {
    fetchImpl = fetch,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    maxRetries = DEFAULT_MAX_RETRIES,
    breakerThreshold = DEFAULT_BREAKER_THRESHOLD,
    breakerCooldownMs = DEFAULT_BREAKER_COOLDOWN_MS,
    idempotencyKey = null,
    logger = null,
  } = {},
) {
  const st = breakerState(provider);
  if (st.state === 'open') {
    if (logger) logger({ event: 'integration_circuit_open', provider, failures: st.failures });
    throw new Error(`circuit open for provider '${provider}' (failures: ${st.failures})`);
  }
  const headers = { ...(options.headers || {}) };
  if (idempotencyKey) headers['idempotency-key'] = idempotencyKey;
  const startedAt = Date.now();
  const done = (result) => recordIntegration({ provider, result, durationMs: Date.now() - startedAt });
  let attempt = 0;
  for (;;) {
    attempt += 1;
    let res;
    try {
      res = await fetchImpl(url, {
        ...options,
        headers,
        signal: AbortSignal.timeout(timeoutMs),
      });
      // The send happened: 4xx is terminal (never retried, never re-sent).
      // The provider is up (client error), so the breaker stays closed, but
      // the outcome still counts as an error for dashboards.
      if (res.status >= 400 && res.status < 500 && res.status !== 429) {
        recordSuccess(provider);
        done('error');
        return res;
      }
      if (res.ok) {
        recordSuccess(provider);
        done('ok');
        return res;
      }
      if (!isRetryable(null, res)) {
        recordFailure(provider, breakerThreshold, breakerCooldownMs);
        done('error');
        return res;
      }
    } catch (err) {
      if (!isRetryable(err, null) || attempt > maxRetries) {
        recordFailure(provider, breakerThreshold, breakerCooldownMs);
        done('error');
        throw err;
      }
      if (logger) logger({ event: 'integration_retry', provider, attempt });
      continue;
    }
    // Retryable HTTP status.
    if (attempt > maxRetries) {
      recordFailure(provider, breakerThreshold, breakerCooldownMs);
      done('error');
      return res;
    }
    if (logger) logger({ event: 'integration_retry', provider, attempt, status: res.status });
  }
}
