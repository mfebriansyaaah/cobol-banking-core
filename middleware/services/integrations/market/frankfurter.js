// Frankfurter FX reference adapter (PR-091): daily mid-rate reference only,
// never a settlement basis. Fetches {rates, date} from a configurable
// endpoint (default frankfurter.app v1 shape); failures reject so the cron
// keeps the last DB snapshot (which self-marks STALE past 24h).
import { resilientFetch, DEFAULT_TIMEOUT_MS } from '../resilience.js';

export const DEFAULT_ENDPOINT = 'https://api.frankfurter.app/v1';

export async function fetchRates(
  { base = 'USD', quotes = ['IDR'] } = {},
  {
    fetchImpl = fetch,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    endpoint = process.env.FRANKFURTER_ENDPOINT || DEFAULT_ENDPOINT,
    idempotencyKey = null,
  } = {},
) {
  const symbols = Array.isArray(quotes) ? quotes.join(',') : quotes;
  const res = await resilientFetch(
    'frankfurter',
    `${endpoint}/latest?base=${encodeURIComponent(base)}&symbols=${encodeURIComponent(symbols)}`,
    { method: 'GET' },
    { fetchImpl, timeoutMs, idempotencyKey },
  );
  if (!res.ok) throw new Error(`frankfurter fetch failed: HTTP ${res.status}`);
  let body;
  try {
    body = await res.json();
  } catch {
    throw new Error('frankfurter fetch rejected (malformed JSON)');
  }
  if (!body || typeof body.rates !== 'object' || !body.rates || !body.date) {
    throw new Error('frankfurter fetch rejected (unexpected shape)');
  }
  const rates = {};
  for (const [quote, rate] of Object.entries(body.rates)) {
    const n = Number(rate);
    if (/^[A-Z]{3}$/.test(quote) && Number.isFinite(n) && n > 0) rates[quote] = n;
  }
  if (!Object.keys(rates).length) throw new Error('frankfurter fetch rejected (no usable rates)');
  return { base, rates, date: body.date };
}

export function createFxProvider(kind, { logger = null } = {}) {
  if (kind === 'mock') {
    return {
      kind,
      async fetchRates({ base = 'USD', quotes = ['IDR'] } = {}) {
        const event = { event: 'fx_rates', base, quotes };
        if (logger) logger(event);
        return { base, rates: Object.fromEntries(quotes.map((q) => [q, 1])), date: '2026-01-01' };
      },
      async health() {
        return { ok: true, provider: 'mock', detail: null };
      },
    };
  }
  if (kind === 'frankfurter') {
    return {
      kind,
      async fetchRates(args, opts) {
        return fetchRates(args, opts);
      },
      async health() {
        return { ok: true, provider: 'frankfurter', detail: null };
      },
    };
  }
  throw new Error(`unknown fx provider '${kind}' (mock|frankfurter)`);
}
