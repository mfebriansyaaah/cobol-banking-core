// Frankfurter FX reference adapter (PR-091): daily mid-rate reference only,
// never a settlement basis. Fetches {rates, date} from a configurable
// endpoint (default frankfurter.app v1 shape); failures reject so the cron
// keeps the last DB snapshot (which self-marks STALE past 24h).
//
// Provider seam for settlement readiness: `FX_PROVIDER=mock|frankfurter|official`.
// `official` speaks the same v1 JSON shape but against a contracted feed
// (`FX_ENDPOINT`, Bearer `FX_API_KEY`) — that is where a BI/bank rate plugs
// in without a code change. Production refuses anything but `official`.
import { resilientFetch, DEFAULT_TIMEOUT_MS } from '../resilience.js';

export const DEFAULT_ENDPOINT = 'https://api.frankfurter.app/v1';
export const FX_PROVIDERS = ['mock', 'frankfurter', 'official'];

export function fxProviderKind() {
  return (process.env.FX_PROVIDER || 'frankfurter').trim().toLowerCase();
}

// Fail fast for the cron entrypoint (production only): demo feeds never set
// settlement-grade rates, and an official feed without endpoint/key cannot run.
export function assertFxConfig() {
  const kind = fxProviderKind();
  if (!FX_PROVIDERS.includes(kind)) {
    throw new Error(`invalid FX_PROVIDER=${JSON.stringify(kind)} (allowed: ${FX_PROVIDERS.join(', ')})`);
  }
  if (process.env.NODE_ENV === 'production' && kind !== 'official') {
    throw new Error(`FX_PROVIDER=${kind} is not settlement-grade (production requires official)`);
  }
  if (kind === 'official' && !process.env.FX_ENDPOINT) {
    throw new Error('FX_ENDPOINT is required with FX_PROVIDER=official');
  }
  if (kind === 'official' && !process.env.FX_API_KEY) {
    throw new Error('FX_API_KEY is required with FX_PROVIDER=official');
  }
  return kind;
}

export async function fetchRates(
  { base = 'USD', quotes = ['IDR'] } = {},
  {
    fetchImpl = fetch,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    endpoint = process.env.FRANKFURTER_ENDPOINT || DEFAULT_ENDPOINT,
    apiKey = null,
    provider = 'frankfurter',
    idempotencyKey = null,
  } = {},
) {
  const symbols = Array.isArray(quotes) ? quotes.join(',') : quotes;
  const headers = apiKey ? { authorization: `Bearer ${apiKey}` } : {};
  const res = await resilientFetch(
    provider,
    `${endpoint}/latest?base=${encodeURIComponent(base)}&symbols=${encodeURIComponent(symbols)}`,
    { method: 'GET', headers },
    { fetchImpl, timeoutMs, idempotencyKey },
  );
  if (!res.ok) throw new Error(`FX fetch failed (${provider}): HTTP ${res.status}`);
  let body;
  try {
    body = await res.json();
  } catch {
    throw new Error(`FX fetch rejected (${provider}): malformed JSON`);
  }
  if (!body || typeof body.rates !== 'object' || !body.rates || !body.date) {
    throw new Error(`FX fetch rejected (${provider}): unexpected shape`);
  }
  const rates = {};
  for (const [quote, rate] of Object.entries(body.rates)) {
    const n = Number(rate);
    if (/^[A-Z]{3}$/.test(quote) && Number.isFinite(n) && n > 0) rates[quote] = n;
  }
  if (!Object.keys(rates).length) throw new Error(`FX fetch rejected (${provider}): no usable rates`);
  return { base, rates, date: body.date };
}

// Official feed fetch: same strict v1 shape, contracted endpoint + key.
export async function fetchOfficialRates(
  args = {},
  {
    fetchImpl = fetch,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    endpoint = process.env.FX_ENDPOINT,
    apiKey = process.env.FX_API_KEY,
    idempotencyKey = null,
  } = {},
) {
  if (!endpoint) throw new Error('FX_ENDPOINT is required with FX_PROVIDER=official');
  if (!apiKey) throw new Error('FX_API_KEY is required with FX_PROVIDER=official');
  return fetchRates(args, { fetchImpl, timeoutMs, endpoint, apiKey, provider: 'official', idempotencyKey });
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
  if (kind === 'official') {
    return {
      kind,
      async fetchRates(args, opts) {
        return fetchOfficialRates(args, opts);
      },
      async health() {
        if (!process.env.FX_ENDPOINT || !process.env.FX_API_KEY) {
          return { ok: false, provider: 'official', detail: 'FX_ENDPOINT/FX_API_KEY missing' };
        }
        return { ok: true, provider: 'official', detail: null };
      },
    };
  }
  throw new Error(`unknown fx provider '${kind}' (mock|frankfurter|official)`);
}
