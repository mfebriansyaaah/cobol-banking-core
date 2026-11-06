import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createCorporateProvider, isLei, lookupLei, searchLeis } from '../../src/integrations/identity/gleif.js';
import { resetBreakers } from '../../src/integrations/resilience.js';
import { resetMetrics, metricsText } from '../../src/observability.js';

const LEI = '529900T8BM49AURSDO55';
const record = {
  data: {
    id: LEI,
    attributes: {
      entity: { legalName: { name: 'Test Bank AS' }, legalAddress: { city: 'Oslo' } },
      registration: { status: 'ISSUED' },
    },
  },
};
const okFetch = (body) => () => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(body) });

test('LEI shape validated locally', () => {
  assert.equal(isLei(LEI), true);
  assert.equal(isLei('short'), false);
  assert.equal(isLei('529900t8bm49aursdo55'), false);
  assert.equal(isLei(null), false);
});

test('lookup parses entity, 404 reads NOT_FOUND', async () => {
  resetBreakers();
  resetMetrics();
  const found = await lookupLei(LEI, { fetchImpl: okFetch(record) });
  assert.equal(found.result, 'FOUND');
  assert.equal(found.entity.legalName, 'Test Bank AS');
  assert.equal(found.entity.status, 'ISSUED');
  assert.equal(found.entity.address, 'Oslo');
  assert.match(metricsText(), /integration_requests_total\{provider="gleif",result="ok"\} 1/);
  const missing = await lookupLei(LEI, { fetchImpl: () => Promise.resolve({ ok: false, status: 404, json: () => Promise.resolve({}) }) });
  assert.equal(missing.result, 'NOT_FOUND');
  assert.deepEqual(await lookupLei('short', { fetchImpl: okFetch(record) }), { result: 'INVALID_INPUT', entity: null });
});

test('lookup failures reject for manual fallback', async () => {
  resetBreakers();
  await assert.rejects(
    lookupLei(LEI, { fetchImpl: () => Promise.resolve({ ok: false, status: 500, json: () => Promise.resolve({}) }) }),
    /HTTP 500/,
  );
  await assert.rejects(
    lookupLei(LEI, { fetchImpl: () => Promise.resolve({ ok: true, status: 200, json: () => Promise.reject(new SyntaxError('x')) }) }),
    /malformed JSON/,
  );
  await assert.rejects(lookupLei(LEI, { fetchImpl: () => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ data: {} }) }) }), /unexpected shape/);
});

test('search returns top matches', async () => {
  resetBreakers();
  const r = await searchLeis('Test Bank', {
    fetchImpl: okFetch({ data: [record.data, { id: 'X', attributes: {} }] }),
  });
  assert.equal(r.result, 'FOUND');
  assert.equal(r.matches.length, 2);
  assert.equal(r.matches[0].lei, LEI);
  assert.deepEqual(await searchLeis('', { fetchImpl: okFetch({}) }), { result: 'INVALID_INPUT', matches: [] });
});

test('mock provider and unknown kind', async () => {
  const mock = createCorporateProvider('mock');
  assert.deepEqual(await mock.lookup('anything'), { result: 'NOT_FOUND', entity: null });
  assert.deepEqual(await mock.health(), { ok: true, provider: 'mock', detail: null });
  assert.throws(() => createCorporateProvider('dun'), /unknown corporate provider/);
});
