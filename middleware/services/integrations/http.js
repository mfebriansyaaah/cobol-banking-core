// Low-level HTTP primitive for integrations (PR-086 companion to
// resilience.js): a single fetch with an AbortSignal timeout and no retry.
// Policy (retry budgets, breakers, metrics) lives in resilience.js; adapters
// that need policy use resilientFetch, adapters that manage their own
// fallback (email outbox, local validators) use this or their own transport.
export async function fetchWithTimeout(url, options = {}, { fetchImpl = fetch, timeoutMs = 4000 } = {}) {
  return fetchImpl(url, {
    ...options,
    signal: AbortSignal.timeout(timeoutMs),
  });
}
