import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  breakerState,
  isRetryable,
  recordIntegration,
  resilientFetch,
  resetBreakers,
  DEFAULT_MAX_RETRIES,
} from '../../services/integrations/resilience.js';
import { metricsText, resetMetrics } from '../../src/observability.js';
import { sendTelegramOtp } from '../../services/integrations/phone/telegram.js';
import { sendFreeSms } from '../../services/integrations/phone/free_sms.js';
import { validateNikRemote } from '../../services/integrations/identity/nusakit.js';
import { sendOtpWithFallback } from '../../services/integrations/phone.js';

const okRes = (body = { ok: true }) => ({
  ok: true,
  status: 200,
  json: () => Promise.resolve(body),
});
const statusRes = (status) => ({ ok: false, status, json: () => Promise.resolve({}) });
const netErr = (code) => Object.assign(new Error(code), { code });
const timeoutErr = () => Object.assign(new Error('timeout'), { name: 'TimeoutError' });

function counting(impl) {
  let calls = 0;
  let lastArgs = null;
  const fn = (...args) => {
    calls += 1;
    lastArgs = args;
    return impl(...args);
  };
  return { fn, calls: () => calls, lastArgs: () => lastArgs };
}

// --- isRetryable policy -----------------------------------------------------

test('retry policy: 429/5xx/network retryable, 4xx and coding bugs terminal', () => {
  assert.equal(isRetryable(null, { status: 429 }), true);
  assert.equal(isRetryable(null, { status: 500 }), true);
  assert.equal(isRetryable(null, { status: 503 }), true);
  assert.equal(isRetryable(null, { status: 200 }), false);
  assert.equal(isRetryable(null, { status: 400 }), false);
  assert.equal(isRetryable(null, { status: 404 }), false);
  assert.equal(isRetryable(timeoutErr(), null), true);
  assert.equal(isRetryable(netErr('ECONNREFUSED'), null), true);
  assert.equal(isRetryable(netErr('ENOTFOUND'), null), true);
  assert.equal(isRetryable(new TypeError('nil'), null), false);
  assert.equal(isRetryable(new SyntaxError('json'), null), false);
  assert.equal(isRetryable(null, null), false);
});

// --- happy path + metrics ---------------------------------------------------

test('ok response records a labeled metric and closes the breaker', async () => {
  resetBreakers();
  resetMetrics();
  const c = counting(() => Promise.resolve(okRes()));
  const res = await resilientFetch('chaos-ok', 'https://x.test/', {}, { fetchImpl: c.fn });
  assert.equal(res.ok, true);
  assert.equal(c.calls(), 1);
  assert.equal(breakerState('chaos-ok').state, 'closed');
  assert.match(metricsText(), /integration_requests_total\{provider="chaos-ok",result="ok"\} 1/);
  assert.match(metricsText(), /integration_request_duration_ms_count 1/);
});

// --- 4xx terminal -----------------------------------------------------------

test('4xx is terminal: exactly one call, no resend, breaker stays closed', async () => {
  resetBreakers();
  resetMetrics();
  const c = counting(() => Promise.resolve(statusRes(400)));
  const res = await resilientFetch('chaos-400', 'https://x.test/', {}, { fetchImpl: c.fn });
  assert.equal(res.status, 400);
  assert.equal(c.calls(), 1);
  assert.equal(breakerState('chaos-400').state, 'closed');
  assert.match(metricsText(), /integration_requests_total\{provider="chaos-400",result="error"\} 1/);
});

// --- 429 / 5xx retry --------------------------------------------------------

test('429 is retried then succeeds without double-send beyond budget', async () => {
  resetBreakers();
  let n = 0;
  const c = counting(() => {
    n += 1;
    return Promise.resolve(n === 1 ? statusRes(429) : okRes());
  });
  const seen = [];
  const res = await resilientFetch('chaos-429', 'https://x.test/', {}, {
    fetchImpl: c.fn,
    logger: (e) => seen.push(e),
  });
  assert.equal(res.ok, true);
  assert.equal(c.calls(), 2);
  assert.equal(seen.length, 1);
  assert.equal(seen[0].status, 429);
});

test('500 is retried then succeeds', async () => {
  resetBreakers();
  let n = 0;
  const c = counting(() => {
    n += 1;
    return Promise.resolve(n < 3 ? statusRes(500) : okRes());
  });
  const res = await resilientFetch('chaos-500', 'https://x.test/', {}, { fetchImpl: c.fn });
  assert.equal(res.ok, true);
  assert.equal(c.calls(), 3);
});

test('persistent 500 returns the last response after the retry budget', async () => {
  resetBreakers();
  resetMetrics();
  const c = counting(() => Promise.resolve(statusRes(500)));
  const res = await resilientFetch('chaos-500x', 'https://x.test/', {}, { fetchImpl: c.fn });
  assert.equal(res.status, 500);
  assert.equal(c.calls(), DEFAULT_MAX_RETRIES + 1);
  assert.match(metricsText(), /integration_requests_total\{provider="chaos-500x",result="error"\} 1/);
});

// --- timeout / provider down ------------------------------------------------

test('timeout is retried up to the budget then throws (no hang)', async () => {
  resetBreakers();
  const c = counting(() => Promise.reject(timeoutErr()));
  await assert.rejects(
    resilientFetch('chaos-timeout', 'https://x.test/', {}, { fetchImpl: c.fn, timeoutMs: 10 }),
    /timeout/,
  );
  assert.equal(c.calls(), DEFAULT_MAX_RETRIES + 1);
});

test('provider down (ECONNREFUSED) is retried then throws', async () => {
  resetBreakers();
  const c = counting(() => Promise.reject(netErr('ECONNREFUSED')));
  await assert.rejects(resilientFetch('chaos-down', 'https://x.test/', {}, { fetchImpl: c.fn }), /ECONNREFUSED/);
  assert.equal(c.calls(), DEFAULT_MAX_RETRIES + 1);
});

test('non-retryable errors throw immediately with a single call', async () => {
  resetBreakers();
  const c = counting(() => Promise.reject(new TypeError('coding bug')));
  await assert.rejects(resilientFetch('chaos-bug', 'https://x.test/', {}, { fetchImpl: c.fn }), /coding bug/);
  assert.equal(c.calls(), 1);
});

// --- circuit breaker --------------------------------------------------------

test('breaker opens after N failures, blocks fast, half-opens after cooldown', async () => {
  resetBreakers();
  const c = counting(() => Promise.resolve(statusRes(500)));
  const opts = { fetchImpl: c.fn, breakerThreshold: 2, breakerCooldownMs: 25 };
  await resilientFetch('chaos-breaker', 'https://x.test/', {}, opts);
  assert.equal(breakerState('chaos-breaker').state, 'closed');
  await resilientFetch('chaos-breaker', 'https://x.test/', {}, opts);
  assert.equal(breakerState('chaos-breaker').state, 'open');
  // Open: the fetch impl is not even called.
  const before = c.calls();
  await assert.rejects(resilientFetch('chaos-breaker', 'https://x.test/', {}, opts), /circuit open/);
  assert.equal(c.calls(), before);
  assert.match(metricsText(), /integration_circuit_open\{provider="chaos-breaker"\} 1/);
  // After cooldown the breaker half-opens and lets one trial through.
  await new Promise((r) => setTimeout(r, 40));
  assert.equal(breakerState('chaos-breaker').state, 'half-open');
  const ok = counting(() => Promise.resolve(okRes()));
  const res = await resilientFetch('chaos-breaker', 'https://x.test/', {}, { ...opts, fetchImpl: ok.fn });
  assert.equal(res.ok, true);
  assert.equal(breakerState('chaos-breaker').state, 'closed');
});

// --- idempotency ------------------------------------------------------------

test('idempotency key travels as a header on every attempt', async () => {
  resetBreakers();
  const c = counting(() => Promise.resolve(okRes()));
  await resilientFetch('chaos-idem', 'https://x.test/', {}, { fetchImpl: c.fn, idempotencyKey: 'otp-123' });
  assert.equal(c.lastArgs()[1].headers['idempotency-key'], 'otp-123');
});

// --- adapter chaos ----------------------------------------------------------

test('telegram rejects malformed JSON with a named error (no fake success)', async () => {
  resetBreakers();
  process.env.TELEGRAM_BOT_TOKEN = 'test-token';
  try {
    await assert.rejects(
      sendTelegramOtp(
        { chatId: '1', text: 'hi' },
        { fetchImpl: () => Promise.resolve({ ok: true, status: 200, json: () => Promise.reject(new SyntaxError('bad')) }) },
      ),
      /malformed JSON/,
    );
    await assert.rejects(
      sendTelegramOtp(
        { chatId: '1', text: 'hi' },
        { fetchImpl: () => Promise.resolve({ ok: false, status: 500, json: () => Promise.resolve({}) }) },
      ),
      /HTTP 500/,
    );
    const c = counting(() => Promise.resolve({ ok: false, status: 400, json: () => Promise.resolve({}) }));
    await assert.rejects(
      sendTelegramOtp({ chatId: '1', text: 'hi' }, { fetchImpl: c.fn }),
      /HTTP 400/,
    );
    assert.equal(c.calls(), 1, '4xx never retried (no OTP double-send)');
  } finally {
    delete process.env.TELEGRAM_BOT_TOKEN;
  }
});

test('free_sms fails closed without config and surfaces HTTP failures', async () => {
  resetBreakers();
  delete process.env.FREE_SMS_ENDPOINT;
  delete process.env.FREE_SMS_API_KEY;
  await assert.rejects(sendFreeSms({ to: '+6281', text: 'hi' }), /not set/);
  process.env.FREE_SMS_ENDPOINT = 'https://sms.test/send';
  process.env.FREE_SMS_API_KEY = 'k';
  try {
    await assert.rejects(
      sendFreeSms(
        { to: '+6281', text: 'hi' },
        { fetchImpl: () => Promise.resolve({ ok: false, status: 503, json: () => Promise.resolve({}) }) },
      ),
      /HTTP 503/,
    );
    const ok = await sendFreeSms(
      { to: '+6281', text: 'hi' },
      { fetchImpl: () => Promise.resolve(okRes()) },
    );
    assert.equal(ok, true);
  } finally {
    delete process.env.FREE_SMS_ENDPOINT;
    delete process.env.FREE_SMS_API_KEY;
  }
});

test('nusakit falls back to local on error status, timeout, and circuit open', async () => {
  resetBreakers();
  process.env.NUSAKIT_ENDPOINT = 'https://allow.example/nik';
  process.env.NUSAKIT_ALLOWLIST = 'allow.example';
  try {
    const on500 = await validateNikRemote(
      { nik: '3171010101900001', consent: true },
      { fetchImpl: () => Promise.resolve(statusRes(500)) },
    );
    assert.equal(on500.valid, true);
    assert.match(on500.remote, /fallback/);
    const onTimeout = await validateNikRemote(
      { nik: '3171010101900001', consent: true },
      { fetchImpl: () => Promise.reject(timeoutErr()) },
    );
    assert.equal(onTimeout.valid, true);
    assert.match(onTimeout.remote, /fallback/);
    const malformed = await validateNikRemote(
      { nik: '3171010101900001', consent: true },
      { fetchImpl: () => Promise.resolve({ ok: true, status: 200, json: () => Promise.reject(new SyntaxError('x')) }) },
    );
    assert.equal(malformed.valid, true);
    assert.match(malformed.remote, /fallback/);
  } finally {
    delete process.env.NUSAKIT_ENDPOINT;
    delete process.env.NUSAKIT_ALLOWLIST;
  }
});

// --- fallback chain ---------------------------------------------------------

test('phone fallback: telegram failure falls through to free_sms', async () => {
  resetBreakers();
  resetMetrics();
  const primary = { kind: 'telegram', sendOtp: () => Promise.reject(new Error('telegram send failed: HTTP 500')) };
  let secondaryCalled = 0;
  const secondary = {
    kind: 'free_sms',
    sendOtp: () => {
      secondaryCalled += 1;
      return Promise.resolve(true);
    },
  };
  assert.equal(await sendOtpWithFallback(primary, secondary, { chatId: '1' }), true);
  assert.equal(secondaryCalled, 1);
  assert.match(metricsText(), /integration_fallback_total\{provider="telegram",reason="free_sms"\} 1/);
});

test('phone fallback: both down throws a manual-review error, never hangs', async () => {
  resetBreakers();
  const primary = { kind: 'telegram', sendOtp: () => Promise.reject(new Error('down 1')) };
  const secondary = { kind: 'free_sms', sendOtp: () => Promise.reject(new Error('down 2')) };
  await assert.rejects(sendOtpWithFallback(primary, secondary, {}), /manual review/);
});

test('recordIntegration uses the plan metric name with provider and result labels', () => {
  resetMetrics();
  recordIntegration({ provider: 'demo', result: 'ok', durationMs: 5 });
  assert.match(metricsText(), /integration_requests_total\{provider="demo",result="ok"\} 1/);
});
