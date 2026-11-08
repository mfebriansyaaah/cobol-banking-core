// Unit tests for server-side derivations (no DB): every fail-closed branch
// must stay covered so the coverage ratchet holds when the gateway grows.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyDerivation, deriveOcr, derivePhoneHash, deriveRisk, deriveScreen } from '../src/derivations.js';
import { ValidationError } from '../src/validation.js';
import { resetQuota } from '../services/integrations/quota.js';

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

test('OCR mock never clears: success still requires human review', async () => {
  const res = await withEnv({ KTP_OCR_PROVIDER: 'mock' }, () => deriveOcr({ imageRef: 'img-123' }));
  assert.deepEqual(res, {
    ocrReviewSignal: 'MANUAL_REVIEW',
    verdict: 'MANUAL_REVIEW',
    reason: 'human-review-required',
  });
});

test('OCR unknown provider fails fast instead of failing open', async () => {
  await assert.rejects(
    withEnv({ KTP_OCR_PROVIDER: 'local' }, () => deriveOcr({ imageRef: 'img-123' })),
    /unknown OCR provider/,
  );
});

test('OCR requires an image reference', async () => {
  await assert.rejects(
    withEnv({ KTP_OCR_PROVIDER: 'mock' }, () => deriveOcr({})),
    ValidationError,
  );
});

test('screening over quota fails closed into manual review without network', async () => {
  resetQuota();
  const res = await withEnv({ SCREENING_PROVIDER: 'opensanctions', QUOTA_OPENSANCTIONS_DAILY: '0' }, () =>
    deriveScreen({ name: 'John Doe', consent: '1' }),
  );
  assert.equal(res.result, 'MANUAL_REVIEW');
  assert.equal(res.provider, 'opensanctions');
  assert.equal(res.providerRef, 'quota-exceeded');
  assert.match(res.queryHash, /^[0-9a-f]{64}$/);
  resetQuota();
});

test('screening mock records dob in the query hash', async () => {
  const res = await withEnv({ SCREENING_PROVIDER: 'mock' }, () =>
    deriveScreen({ name: 'John Doe', dob: '1990-01-01', consent: '1' }),
  );
  assert.equal(res.result, 'CLEAR');
  assert.match(res.queryHash, /^[0-9a-f]{64}$/);
});

test('screening without consent is rejected', async () => {
  await assert.rejects(
    withEnv({ SCREENING_PROVIDER: 'mock' }, () => deriveScreen({ name: 'John Doe' })),
    ValidationError,
  );
});

test('risk derivation needs the socket IP, never a client field', async () => {
  await assert.rejects(deriveRisk({ email: 'a@b.com' }, { req: {} }), /client IP unavailable/);
});

test('phone derivation rejects unparseable numbers', async () => {
  await assert.rejects(derivePhoneHash({ phone: 'not-a-number' }), ValidationError);
});

test('applyDerivation ignores unknown actions and dispatches known ones', async () => {
  assert.deepEqual(await applyDerivation('NOPE_NOT_REAL', { a: 'b' }), {});
  const res = await applyDerivation('OTP_LINK_BEGIN', { phone: '+6281234567890' });
  assert.match(res.phoneHash, /^[0-9a-f]{64}$/);
});
