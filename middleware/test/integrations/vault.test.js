import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import {
  assertObjectAllowed,
  deleteObject,
  objectKey,
  putObject,
  sha256Hex,
  signRequest,
  vaultConfig,
} from '../../src/integrations/documents/storage.js';
import { scanBuffer } from '../../src/integrations/documents/scan.js';
import { retentionDue } from '../../src/integrations/documents/retention.js';
import { resetBreakers } from '../../src/integrations/resilience.js';
import { resetMetrics, metricsText } from '../../src/observability.js';

const CFG = {
  endpoint: 'http://minio.test',
  bucket: 'documents',
  region: 'us-east-1',
  accessKey: 'AK',
  secretKey: 'SK',
  kmsKeyId: 'kms-1',
};
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d]);

function fakeS3(handler) {
  return async (url, opts) => {
    assert.match(url, /^http:\/\/minio\.test\/documents\//);
    assert.ok(opts.headers.Authorization.startsWith('AWS4-HMAC-SHA256'));
    return handler(url, opts);
  };
}

// Fake ClamAV: minimal INSTREAM speaker over an EventEmitter socket.
function fakeClam(reply) {
  let socket;
  const connect = () => {
    socket = new EventEmitter();
    socket.write = () => true;
    socket.destroy = () => socket.emit('close');
    queueMicrotask(() => {
      socket.emit('data', Buffer.from(reply));
      socket.emit('close');
    });
    return socket;
  };
  return { connect, socket: () => socket };
}

test('object gate: size, type, key shape, hash', () => {
  assert.deepEqual(assertObjectAllowed({ bytes: PNG, mime: 'image/png' }), { ok: true });
  assert.equal(assertObjectAllowed({ bytes: Buffer.alloc(6 * 1024 * 1024), mime: 'image/png' }).ok, false);
  assert.equal(assertObjectAllowed({ bytes: PNG, mime: 'text/html' }).ok, false);
  assert.equal(assertObjectAllowed({ bytes: null, mime: 'image/png' }).ok, false);
  assert.match(objectKey(), /^ktp\/[0-9a-z]+-[0-9a-f]{16}$/);
  assert.notEqual(objectKey(), objectKey());
  assert.match(sha256Hex(PNG), /^[0-9a-f]{64}$/);
});

test('SigV4 signs PUT with KMS headers', async () => {
  resetBreakers();
  resetMetrics();
  let seenHeaders = null;
  const ok = await putObject(
    { key: 'ktp/abc', bytes: PNG, mime: 'image/png' },
    {
      cfg: CFG,
      fetchImpl: fakeS3(async (url, opts) => {
        seenHeaders = opts.headers;
        return { ok: true, status: 200 };
      }),
    },
  );
  assert.equal(ok.key, 'ktp/abc');
  assert.equal(ok.kmsKeyId, 'kms-1');
  assert.equal(seenHeaders['x-amz-server-side-encryption'], 'aws:kms');
  assert.match(metricsText(), /integration_requests_total\{provider="minio",result="ok"\} 1/);
});

test('store refuses without config and surfaces HTTP errors', async () => {
  resetBreakers();
  await assert.rejects(
    putObject({ key: 'k', bytes: PNG, mime: 'image/png' }, { cfg: { ...CFG, endpoint: '' } }),
    /not set/,
  );
  await assert.rejects(
    putObject(
      { key: 'k', bytes: PNG, mime: 'image/png' },
      { cfg: CFG, fetchImpl: fakeS3(async () => ({ ok: false, status: 500 })) },
    ),
    /HTTP 500/,
  );
  assert.equal(
    await deleteObject('ktp/gone', { cfg: CFG, fetchImpl: fakeS3(async () => ({ ok: false, status: 404 })) }),
    true,
  );
});

test('scan: clean stores, infected rejects, timeout quarantines', async () => {
  const clean = await scanBuffer(PNG, { connect: fakeClam('stream: OK').connect });
  assert.equal(clean.verdict, 'CLEAN');
  const infected = await scanBuffer(PNG, { connect: fakeClam('stream: Eicar-Test-Signature FOUND').connect });
  assert.equal(infected.verdict, 'INFECTED');
  const hanging = await scanBuffer(PNG, {
    connect: () => {
      const s = new EventEmitter();
      s.write = () => true;
      s.destroy = () => {};
      return s;
    },
    timeoutMs: 30,
  });
  assert.equal(hanging.verdict, 'QUARANTINE');
  const down = await scanBuffer(PNG, {
    connect: () => {
      throw new Error('refused');
    },
  });
  assert.equal(down.verdict, 'QUARANTINE');
});

test('retention: hold wins, infected immediate, expiry by age', () => {
  const now = new Date('2026-11-06T00:00:00Z').getTime();
  assert.deepEqual(retentionDue({ storedAt: '2026-11-01', now }).due, false);
  assert.deepEqual(retentionDue({ storedAt: '2026-09-01', now }), { due: true, reason: 'expired' });
  assert.deepEqual(retentionDue({ storedAt: '2026-09-01', legalHold: true, now }), {
    due: false,
    reason: 'legal-hold',
  });
  assert.deepEqual(retentionDue({ storedAt: '2026-11-05', infected: true, now }), { due: true, reason: 'infected' });
  assert.deepEqual(
    retentionDue({ storedAt: '2026-11-05', verifiedAt: '2026-11-05', retentionDays: 30, now }).reason,
    'retained',
  );
});

test('vaultConfig reads env; signRequest carries method in scope', () => {
  const saved = process.env.VAULT_BUCKET;
  process.env.VAULT_BUCKET = 'ktp-docs';
  try {
    assert.equal(vaultConfig().bucket, 'ktp-docs');
  } finally {
    if (saved === undefined) delete process.env.VAULT_BUCKET;
    else process.env.VAULT_BUCKET = saved;
  }
  const h = signRequest({
    method: 'PUT',
    url: 'http://minio.test/documents/k',
    region: 'us-east-1',
    accessKey: 'A',
    secretKey: 'S',
    mime: 'image/png',
  });
  assert.match(h.Authorization, /SignedHeaders=.*content-type/);
});
