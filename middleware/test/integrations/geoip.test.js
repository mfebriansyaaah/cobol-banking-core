import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createGeoProvider, isPrivateIp, resolveGeo } from '../../services/integrations/risk/geoip.js';
import { flagMismatch, hashIp, noteRisk } from '../../services/integrations/risk/risk_events.js';
import { resetBreakers } from '../../services/integrations/resilience.js';
import { resetMetrics, metricsText } from '../../src/observability.js';

const IP = '203.0.113.7';
const geoBody = { country_code: 'ID', city: 'Jakarta', asn: 'AS4761' };
const okFetch = () => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(geoBody) });
const withEndpoint = { endpoint: 'https://geo.example', timeoutMs: 500 };

test('private and loopback IPs short-circuit without network', async () => {
  resetBreakers();
  for (const ip of ['10.1.2.3', '172.16.0.1', '192.168.1.1', '127.0.0.1', '::1', '']) {
    assert.equal(isPrivateIp(ip), true, ip || '(empty)');
    let called = 0;
    const r = await resolveGeo(ip, { ...withEndpoint, fetchImpl: () => ((called += 1), okFetch()) });
    assert.equal(r.country, 'UNKNOWN');
    assert.equal(called, 0, `no network for ${ip}`);
  }
  assert.equal(isPrivateIp('8.8.8.8'), false);
  assert.equal(isPrivateIp('203.0.113.7'), false);
});

test('public IP resolves country/city/asn; failures read UNKNOWN', async () => {
  resetBreakers();
  resetMetrics();
  const r = await resolveGeo(IP, { ...withEndpoint, fetchImpl: okFetch });
  assert.deepEqual(r, { country: 'ID', city: 'Jakarta', asn: 'AS4761' });
  assert.match(metricsText(), /integration_requests_total\{provider="geoip",result="ok"\} 1/);
  const noEndpoint = await resolveGeo(IP, {});
  assert.equal(noEndpoint.country, 'UNKNOWN');
  const down = await resolveGeo(IP, { ...withEndpoint, fetchImpl: () => Promise.reject(new Error('down')) });
  assert.equal(down.country, 'UNKNOWN');
  const bad = await resolveGeo(IP, {
    ...withEndpoint,
    fetchImpl: () => Promise.resolve({ ok: true, status: 200, json: () => Promise.reject(new SyntaxError('x')) }),
  });
  assert.equal(bad.country, 'UNKNOWN');
  const junk = await resolveGeo(IP, {
    ...withEndpoint,
    fetchImpl: () => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ country_code: 'XX1' }) }),
  });
  assert.equal(junk.country, 'UNKNOWN');
});

test('hashIp is stable hex; mismatch flags are pure', () => {
  assert.match(hashIp(IP), /^[0-9a-f]{64}$/);
  assert.equal(hashIp(IP), hashIp(IP));
  assert.notEqual(hashIp(IP), hashIp('8.8.8.8'));
  assert.deepEqual(flagMismatch({ country: 'ID' }, 'ID'), []);
  assert.deepEqual(flagMismatch({ country: 'US' }, 'ID'), ['COUNTRY_MISMATCH']);
  assert.deepEqual(flagMismatch({ country: 'UNKNOWN' }, 'ID'), ['GEO_UNKNOWN']);
  assert.deepEqual(flagMismatch({ country: 'UNKNOWN' }, null), ['GEO_UNKNOWN']);
});

test('noteRisk hashes, flags, and never carries the raw IP', async () => {
  const n = await noteRisk(
    { email: 'a@t.co', ip: IP, lastCountry: 'US' },
    { resolve: async (ip) => ({ country: 'ID', city: 'Jakarta', asn: 'AS1', _ip: ip }) },
  );
  assert.equal(n.country, 'ID');
  assert.equal(n.flags, 'COUNTRY_MISMATCH');
  assert.match(n.ipHash, /^[0-9a-f]{64}$/);
  assert.ok(!JSON.stringify(n).includes(IP), 'raw IP in notation');
  const m = await noteRisk(
    { email: 'a@t.co', ip: '10.0.0.1', flags: ['NEW_DEVICE'] },
    {
      resolve: async () => ({ country: 'UNKNOWN', city: null, asn: null }),
    },
  );
  assert.equal(m.flags, 'NEW_DEVICE:GEO_UNKNOWN');
  await assert.rejects(noteRisk({ email: '', ip: IP }), /email and ip/);
});

test('geo provider health and unknown kind', async () => {
  const mock = createGeoProvider('mock');
  assert.equal((await mock.resolve({ ip: '10.0.0.1' })).country, 'UNKNOWN');
  assert.deepEqual(await mock.health(), { ok: true, provider: 'mock', detail: null });
  const ipapi = createGeoProvider('ipapi');
  assert.equal((await ipapi.health()).ok, false);
  assert.throws(() => createGeoProvider('maxmind'), /unknown geo provider/);
});
