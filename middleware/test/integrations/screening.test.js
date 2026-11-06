import { test } from 'node:test';
import assert from 'node:assert/strict';
import { writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  assertScreeningLicense,
  createScreeningProvider,
  queryHash,
  screenName,
} from '../../src/integrations/screening/opensanctions.js';
import { matchLists } from '../../src/integrations/screening/lists.js';
import { resetMetrics, metricsText } from '../../src/observability.js';
import { resetBreakers } from '../../src/integrations/resilience.js';

const okMatch = (matches) => () => Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve({ matches }) });

function withEnv(vars, fn) {
  const saved = {};
  for (const k of Object.keys(vars)) {
    saved[k] = process.env[k];
    if (vars[k] === undefined) delete process.env[k];
    else process.env[k] = vars[k];
  }
  try {
    return fn();
  } finally {
    for (const k of Object.keys(vars)) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  }
}

const EP = 'https://allow.example/yente';
const AL = 'allow.example';
const baseOpts = (fetchImpl) => ({
  fetchImpl,
  endpoint: EP,
  allowlist: [AL],
  timeoutMs: 500,
});

test('queryHash is stable, hex, and never the raw name', () => {
  const h = queryHash('John Doe', '1990-05-01');
  assert.match(h, /^[0-9a-f]{64}$/);
  assert.equal(h, queryHash('  john doe ', '1990-05-01'));
  assert.ok(!h.includes('john'));
  assert.notEqual(h, queryHash('John Doe', '1991-05-01'));
});

test('screening needs consent, endpoint, and allowlist (else SKIPPED)', async () => {
  resetBreakers();
  assert.equal((await screenName({ name: 'John Doe', consent: false }, baseOpts(okMatch([])))).result, 'SKIPPED');
  assert.equal(
    (await screenName({ name: 'John Doe', consent: true }, { ...baseOpts(okMatch([])), endpoint: '' })).result,
    'SKIPPED',
  );
  assert.equal(
    (await screenName({ name: 'John Doe', consent: true }, { ...baseOpts(okMatch([])), allowlist: ['other.example'] }))
      .result,
    'SKIPPED',
  );
  assert.equal((await screenName({ name: '', consent: true }, baseOpts(okMatch([])))).result, 'INVALID_INPUT');
});

test('no matches -> CLEAR; matches -> POTENTIAL_MATCH (never auto-clear)', async () => {
  resetBreakers();
  resetMetrics();
  const clear = await screenName({ name: 'Jane Doe', dob: '1990-01-01', consent: true }, baseOpts(okMatch([])));
  assert.equal(clear.result, 'CLEAR');
  assert.equal(clear.score, 0);
  assert.match(clear.queryHash, /^[0-9a-f]{64}$/);
  const hit = await screenName(
    { name: 'John Doe', dob: '1970-01-01', consent: true },
    baseOpts(okMatch([{ score: 0.92, id: 'Q123' }])),
  );
  assert.equal(hit.result, 'POTENTIAL_MATCH');
  assert.equal(hit.score, 0.92);
  assert.equal(hit.ref, 'Q123');
  assert.match(metricsText(), /integration_requests_total\{provider="opensanctions",result="ok"\} 2/);
});

test('provider down fails closed to MANUAL_REVIEW, never CLEAR', async () => {
  resetBreakers();
  const down = await screenName(
    { name: 'John Doe', consent: true },
    baseOpts(() => Promise.reject(Object.assign(new Error('refused'), { code: 'ECONNREFUSED' }))),
  );
  assert.equal(down.result, 'MANUAL_REVIEW');
  assert.match(down.ref, /fallback/);
  const http500 = await screenName(
    { name: 'John Doe', consent: true },
    baseOpts(() => Promise.resolve({ ok: false, status: 500, json: () => Promise.resolve({}) })),
  );
  assert.equal(http500.result, 'MANUAL_REVIEW');
  const malformed = await screenName(
    { name: 'John Doe', consent: true },
    baseOpts(() => Promise.resolve({ ok: true, status: 200, json: () => Promise.reject(new SyntaxError('x')) })),
  );
  assert.equal(malformed.result, 'MANUAL_REVIEW');
});

test('list fallback catches what the provider missed', async () => {
  resetBreakers();
  const p = join(tmpdir(), `lists090-${process.pid}.csv`);
  writeFileSync(p, 'id,last,first\n1,DOE,John\n2,SMITH,Jane\n');
  const saved = process.env.SCREENING_LISTS_PATH;
  process.env.SCREENING_LISTS_PATH = p;
  try {
    const hit = await screenName(
      { name: 'John Doe', consent: true },
      baseOpts(() => Promise.reject(new Error('down'))),
    );
    assert.equal(hit.result, 'POTENTIAL_MATCH');
    assert.match(hit.ref, /^lists:/);
    const clear = await screenName(
      { name: 'Nobody Here', consent: true },
      baseOpts(() => Promise.reject(new Error('down'))),
    );
    // Lists have an opinion (CLEAR) when the file reads clean.
    assert.equal(clear.result, 'CLEAR');
  } finally {
    if (saved === undefined) delete process.env.SCREENING_LISTS_PATH;
    else process.env.SCREENING_LISTS_PATH = saved;
    unlinkSync(p);
  }
});

test('matchLists is a baseline heuristic with file-missing null', () => {
  const p = join(tmpdir(), `lists090b-${process.pid}.csv`);
  writeFileSync(p, '1,DOE,John\n2,SMITH,Jane\n3,VAN HALEN,Eddie\n');
  try {
    const hit = matchLists('John Doe', { path: p });
    assert.equal(hit.result, 'POTENTIAL_MATCH');
    assert.match(hit.ref, /^lists:/);
    assert.equal(matchLists('Nobody Here', { path: p }).result, 'CLEAR');
    assert.equal(matchLists('John Doe', { path: '/nonexistent.csv' }), null);
    assert.equal(matchLists('John Doe', { path: undefined }), null);
  } finally {
    unlinkSync(p);
  }
});

test('license guard: commercial needs a key, unknown modes rejected', () => {
  withEnv({ SCREENING_LICENSE: undefined, SCREENING_LICENSE_KEY: undefined }, () => {
    assert.equal(assertScreeningLicense(), 'noncommercial');
  });
  withEnv({ SCREENING_LICENSE: 'commercial', SCREENING_LICENSE_KEY: undefined }, () => {
    assert.throws(() => assertScreeningLicense(), /SCREENING_LICENSE_KEY/);
  });
  withEnv({ SCREENING_LICENSE: 'commercial', SCREENING_LICENSE_KEY: 'k' }, () => {
    assert.equal(assertScreeningLicense(), 'commercial');
  });
  withEnv({ SCREENING_LICENSE: 'pirate' }, () => {
    assert.throws(() => assertScreeningLicense(), /invalid SCREENING_LICENSE/);
  });
});

test('mock provider is CLEAR with redacted logs; unknown kind throws', async () => {
  const seen = [];
  const mock = createScreeningProvider('mock', { logger: (e) => seen.push(e) });
  const r = await mock.screen({ name: 'John Doe' });
  assert.equal(r.result, 'CLEAR');
  assert.ok(!JSON.stringify(seen).includes('John Doe'));
  assert.deepEqual(await mock.health(), { ok: true, provider: 'mock', detail: null });
  assert.throws(() => createScreeningProvider('pigeon'), /unknown screening provider/);
  const remote = createScreeningProvider('opensanctions');
  assert.equal((await remote.health()).ok, false);
  process.env.SCREENING_ENDPOINT = EP;
  try {
    assert.equal((await remote.health()).ok, true);
  } finally {
    delete process.env.SCREENING_ENDPOINT;
  }
});
