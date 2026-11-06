import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createFxProvider, fetchRates } from '../../src/integrations/market/frankfurter.js';
import { syncRates } from '../../../scripts/cron/fetch_fx_rates.mjs';
import { resetBreakers } from '../../src/integrations/resilience.js';
import { resetMetrics, metricsText } from '../../src/observability.js';

const body = { base: 'USD', date: '2026-11-01', rates: { IDR: 16500.5, EUR: 0.92 } };
const okFetch = () => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(body) });

test('fetchRates parses rates + date, drops junk quotes', async () => {
  resetBreakers();
  resetMetrics();
  const r = await fetchRates({ base: 'USD', quotes: ['IDR', 'EUR'] }, { fetchImpl: okFetch });
  assert.equal(r.base, 'USD');
  assert.equal(r.rates.IDR, 16500.5);
  assert.equal(r.date, '2026-11-01');
  assert.match(metricsText(), /integration_requests_total\{provider="frankfurter",result="ok"\} 1/);
  const junk = await fetchRates(
    { base: 'USD', quotes: ['IDR'] },
    {
      fetchImpl: () =>
        Promise.resolve({
          ok: true,
          status: 200,
          json: () => Promise.resolve({ date: '2026-11-01', rates: { IDR: 1, XX: -2, nope: 'x' } }),
        }),
    },
  );
  assert.deepEqual(Object.keys(junk.rates), ['IDR']);
});

test('fetchRates rejects HTTP errors, malformed JSON, and empty rates', async () => {
  resetBreakers();
  await assert.rejects(
    fetchRates(
      { quotes: ['IDR'] },
      { fetchImpl: () => Promise.resolve({ ok: false, status: 500, json: () => Promise.resolve({}) }) },
    ),
    /HTTP 500/,
  );
  await assert.rejects(
    fetchRates(
      { quotes: ['IDR'] },
      { fetchImpl: () => Promise.resolve({ ok: true, status: 200, json: () => Promise.reject(new SyntaxError('x')) }) },
    ),
    /malformed JSON/,
  );
  await assert.rejects(
    fetchRates(
      { quotes: ['IDR'] },
      {
        fetchImpl: () =>
          Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ date: '2026-11-01', rates: {} }) }),
      },
    ),
    /no usable rates/,
  );
  await assert.rejects(
    fetchRates(
      { quotes: ['IDR'] },
      { fetchImpl: () => Promise.reject(Object.assign(new Error('down'), { code: 'ECONNREFUSED' })) },
    ),
    /down/,
  );
});

test('syncRates stores every pair, keeps old snapshot on failure', async () => {
  const stored = [];
  const r = await syncRates({
    fetchImpl: okFetch,
    store: async (b, q, rate, d) => {
      stored.push([b, q, rate, d]);
      return 'SUCCESS|FX_STORED';
    },
    base: 'USD',
    quotes: ['IDR', 'EUR'],
  });
  assert.equal(r.stored, 2);
  assert.deepEqual(stored[0], ['USD', 'IDR', 16500.5, '2026-11-01']);
  await assert.rejects(
    syncRates({ fetchImpl: () => Promise.reject(new Error('down')), store: async () => 'x' }),
    /down/,
  );
  // A refused store aborts the sync loudly (cron exits 1, snapshot stands).
  await assert.rejects(syncRates({ fetchImpl: okFetch, store: async () => 'ERROR|FORBIDDEN' }), /store refused/);
});

test('mock fx provider and unknown kind', async () => {
  const mock = createFxProvider('mock');
  const r = await mock.fetchRates({ base: 'USD', quotes: ['IDR'] });
  assert.equal(r.rates.IDR, 1);
  assert.deepEqual(await mock.health(), { ok: true, provider: 'mock', detail: null });
  assert.throws(() => createFxProvider('ecb'), /unknown fx provider/);
});
