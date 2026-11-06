import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseNik, nikHandle } from '../../src/integrations/identity/local_nik.js';
import { validateNikRemote } from '../../src/integrations/identity/nusakit.js';

// Reference date pinned per case so age math never flakes at year bounds.
const REF = new Date(Date.UTC(2026, 4, 15)); // 2026-05-15

test('valid male NIK parses with region, gender, age', () => {
  assert.deepEqual(parseNik('3171010101900001', REF), {
    valid: true,
    level: 'STRUCTURAL',
    region: { province: 'DKI JAKARTA', regency: 'KOTA ADM. JAKARTA PUSAT' },
    gender: 'male',
    age: 36,
    reason: null,
  });
});

test('female +40 day segment parses', () => {
  const r = parseNik('3171015001900001', REF);
  assert.equal(r.valid, true);
  assert.equal(r.gender, 'female');
  assert.equal(r.age, 36);
});

test('leap-day birthdays validate only on leap years', () => {
  assert.equal(parseNik('3171012902960001', REF).valid, true); // 1996 leap
  assert.equal(parseNik('3171012902950001', REF).valid, false); // 1995 not leap
});

test('31 February never exists', () => {
  assert.deepEqual(parseNik('3171013102900001', REF), {
    valid: false,
    reason: 'nonexistent calendar date',
  });
});

test('fake region codes rejected', () => {
  assert.equal(parseNik('9911010101900001', REF).reason, 'unknown province code');
  assert.equal(parseNik('3199010101900001', REF).reason, 'unknown regency code');
});

test('under-17 rejected for KYC minimum', () => {
  assert.deepEqual(parseNik('3171010101200001', REF), {
    valid: false,
    reason: 'under 17 (KYC minimum)',
  });
});

test('zero serial rejected', () => {
  assert.deepEqual(parseNik('3171010101900000', REF), {
    valid: false,
    reason: 'zero serial',
  });
});

test('malformed inputs rejected', () => {
  for (const bad of ['123', 'abcdefghijklmnop', '', null, '31710101019000a1']) {
    assert.equal(parseNik(bad, REF).valid, false, String(bad));
  }
});

test('nikHandle stores HMAC + last4, never raw', () => {
  const h = nikHandle('3171010101900001', 's3cret');
  assert.equal(h.last4, '0001');
  assert.match(h.hmac, /^[0-9a-f]{64}$/);
  assert.ok(!JSON.stringify(h).includes('3171010101900001'));
  assert.throws(() => nikHandle('3171010101900001', ''), /server secret/);
  assert.notEqual(nikHandle('3171010101900001', 'other-secret').hmac, h.hmac);
});

test('remote adapter skips without consent/endpoint and falls back on error', async () => {
  const noRemote = await validateNikRemote({ nik: '3171010101900001', consent: false });
  assert.equal(noRemote.valid, true);
  assert.match(noRemote.remote, /skipped/);
  const skippedNoEndpoint = await validateNikRemote(
    { nik: '3171010101900001', consent: true },
    {
      fetchImpl: () => Promise.reject(new Error('boom')),
    },
  );
  assert.equal(skippedNoEndpoint.valid, true);
  // No endpoint configured in this branch: skipped, not fallback. The
  // fallback path is covered below with endpoint + allowlist set.
  process.env.NUSAKIT_ENDPOINT = 'https://allow.example/nik';
  process.env.NUSAKIT_ALLOWLIST = 'allow.example';
  try {
    const failing = await validateNikRemote(
      { nik: '3171010101900001', consent: true },
      { fetchImpl: () => Promise.reject(new Error('boom')) },
    );
    assert.equal(failing.valid, true);
    assert.match(failing.remote, /fallback/);
    const ok = await validateNikRemote(
      { nik: '3171010101900001', consent: true },
      {
        fetchImpl: () => Promise.resolve({ ok: true, json: () => Promise.resolve({ verdict: 'match' }) }),
      },
    );
    assert.equal(ok.remote, 'match');
  } finally {
    delete process.env.NUSAKIT_ENDPOINT;
    delete process.env.NUSAKIT_ALLOWLIST;
  }
});
