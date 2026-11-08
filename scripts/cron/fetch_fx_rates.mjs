// Daily FX reference sync (PR-091): Frankfurter -> FX_RATE_STORE via the
// COBOL invoker (same pattern as the outbox worker). Failures keep the last
// DB snapshot (GET self-marks STALE past 24h); the cron never writes partial
// pairs. Usage: FX_CRON_ACTOR=admin@example.com FX_QUOTES=IDR,EUR,SGD
//   node scripts/cron/fetch_fx_rates.mjs [--once]
import {
  createFxProvider,
  fxProviderKind,
  assertFxConfig,
} from '../../middleware/services/integrations/market/frankfurter.js';
import { invoke } from '../../middleware/src/invoker.js';
import { resetPool } from '../../middleware/src/pool.js';

export async function syncRates({ fetchImpl = fetch, store = null, base, quotes, date, provider = null } = {}) {
  const kind = provider || fxProviderKind();
  const fx = createFxProvider(kind);
  const storeFn =
    store ||
    (async (b, q, rate, d, actor) => {
      const raw = await invoke('FX_RATE_STORE', [b, q, String(rate), kind, d, actor]);
      if (!String(raw).startsWith('SUCCESS|')) throw new Error(`store refused: ${raw}`);
      return raw;
    });
  const fetched = await fx.fetchRates({ base, quotes }, { fetchImpl });
  const stored = [];
  for (const [quote, rate] of Object.entries(fetched.rates)) {
    const raw = await storeFn(fetched.base, quote, rate, date ?? fetched.date, process.env.FX_CRON_ACTOR, kind);
    if (!String(raw).startsWith('SUCCESS|')) throw new Error(`store refused: ${raw}`);
    stored.push(raw);
  }
  return { date: fetched.date, stored: stored.length };
}

const actor = process.env.FX_CRON_ACTOR;
// Only run the sync when executed as the cron entrypoint (imported by tests
// otherwise: under node --test argv[1] is the test file, never this script).
const direct = typeof process.argv[1] === 'string' && process.argv[1].endsWith('scripts/cron/fetch_fx_rates.mjs');
if (!direct) {
  // Imported (tests): export syncRates only.
} else if (!actor) {
  console.error('FX_CRON_ACTOR is required (admin/cron identity for FX_RATE_STORE)');
  process.exitCode = 1;
} else {
  let kind = null;
  try {
    kind = assertFxConfig();
  } catch (err) {
    console.error(`fx sync refused: ${err.message}`);
    process.exitCode = 1;
  }
  if (kind) {
    const base = process.env.FX_BASE || 'USD';
    const quotes = (process.env.FX_QUOTES || 'IDR,EUR,SGD')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    syncRates({ base, quotes, provider: kind })
      .then((r) => console.log(`fx sync ok: ${r.stored} pair(s) @ ${r.date} [${kind}]`))
      .catch((err) => {
        console.error(`fx sync failed (last snapshot stands): ${err.message}`);
        process.exitCode = 1;
      })
      .finally(async () => {
        // Drop pooled COBOL workers so the cron process actually terminates.
        await resetPool();
      });
  }
}
