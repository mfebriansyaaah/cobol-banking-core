import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import {
  assertObjectAllowed,
  assertVaultConfig,
  deleteObject,
  objectKey,
  putObject,
  sha256Hex,
  signRequest,
  vaultConfig,
} from '../../services/integrations/documents/storage.js';
import { scanBuffer } from '../../services/integrations/documents/scan.js';
import { retentionDue, sweepRetention } from '../../services/integrations/documents/retention.js';
import { resetBreakers } from '../../services/integrations/resilience.js';
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

test('production vault writes require a KMS key id', () => {
  const savedEnv = process.env.NODE_ENV;
  const savedEndpoint = process.env.VAULT_ENDPOINT;
  const savedKey = process.env.VAULT_KMS_KEY_ID;
  try {
    process.env.NODE_ENV = 'production';
    process.env.VAULT_ENDPOINT = 'https://minio.prod';
    delete process.env.VAULT_KMS_KEY_ID;
    assert.throws(() => assertVaultConfig(), /VAULT_KMS_KEY_ID is required/);
    process.env.VAULT_KMS_KEY_ID = 'kms-prod-1';
    assert.equal(assertVaultConfig().kmsKeyId, 'kms-prod-1');
    delete process.env.VAULT_ENDPOINT;
    delete process.env.VAULT_KMS_KEY_ID;
    assert.doesNotThrow(() => assertVaultConfig());
    process.env.NODE_ENV = 'test';
    process.env.VAULT_ENDPOINT = 'https://minio.prod';
    assert.doesNotThrow(() => assertVaultConfig());
  } finally {
    if (savedEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = savedEnv;
    if (savedEndpoint === undefined) delete process.env.VAULT_ENDPOINT;
    else process.env.VAULT_ENDPOINT = savedEndpoint;
    if (savedKey === undefined) delete process.env.VAULT_KMS_KEY_ID;
    else process.env.VAULT_KMS_KEY_ID = savedKey;
  }
});

test('KMS key id pins at write time (rotation safety)', async () => {
  resetBreakers();
  const seen = [];
  const put = (kmsKeyId) =>
    putObject(
      { key: 'ktp/rot', bytes: PNG, mime: 'image/png' },
      {
        cfg: { ...CFG, kmsKeyId },
        fetchImpl: fakeS3(async (url, opts) => {
          seen.push(opts.headers);
          return { ok: true, status: 200 };
        }),
      },
    );
  // Stored under key A, the record pins A even after config moves to B.
  const a = await put('kms-A');
  assert.equal(a.kmsKeyId, 'kms-A');
  assert.equal(seen[0]['x-amz-server-side-encryption-aws-kms-key-id'], 'kms-A');
  const b = await put('kms-B');
  assert.equal(b.kmsKeyId, 'kms-B');
  assert.equal(seen[1]['x-amz-server-side-encryption-aws-kms-key-id'], 'kms-B');
  assert.equal(a.kmsKeyId, 'kms-A');
  // Without a key id there are no SSE headers and the record says so: the
  // dev-vs-prod boundary is visible, never silent.
  const plain = await put('');
  assert.equal(plain.kmsKeyId, null);
  assert.equal(seen[2]['x-amz-server-side-encryption'], undefined);
});

test('retention sweep at scale deletes exactly the due set', async () => {
  const now = new Date('2026-11-06T00:00:00Z').getTime();
  const old = '2026-09-01';
  const recent = '2026-11-05';
  const objects = [];
  for (let i = 0; i < 200; i += 1) {
    const kind = i % 4;
    objects.push({
      key: `ktp/obj-${i}`,
      sha256: `hash-${i}`,
      storedAt: kind === 0 || kind === 1 ? old : recent,
      legalHold: kind === 1,
      infected: kind === 3,
    });
  }
  // kind 0 (expired, 50) + kind 3 (infected, 50) are due; kind 1 is held,
  // kind 2 is recent. The deleter fails on one due key to prove a single
  // failure is reported, not fatal.
  const deletedKeys = [];
  const audit = [];
  const summary = await sweepRetention(objects, {
    now,
    deleteOne: async (key) => {
      if (key === 'ktp/obj-0') throw new Error('S3 503');
      deletedKeys.push(key);
      return true;
    },
    logger: (line) => audit.push(line),
  });
  assert.equal(summary.checked, 200);
  assert.equal(summary.deleted.length, 99);
  assert.equal(summary.failed.length, 1);
  assert.equal(summary.failed[0].key, 'ktp/obj-0');
  assert.equal(summary.kept.length, 100);
  assert.ok(
    deletedKeys.every(
      (k) => Number(k.slice('ktp/obj-'.length)) % 4 !== 1 && Number(k.slice('ktp/obj-'.length)) % 4 !== 2,
    ),
  );
  assert.ok(!deletedKeys.includes('ktp/obj-1'), 'legal hold survives');
  assert.ok(deletedKeys.includes('ktp/obj-3'), 'infected goes even when recent');
  // Audit lines carry key + hash, never bytes.
  const delLines = audit.filter((l) => l.event === 'retention_deleted');
  assert.equal(delLines.length, 99);
  assert.ok(delLines.every((l) => l.key && l.sha256 && !('bytes' in l)));
  assert.equal(audit.filter((l) => l.event === 'retention_delete_failed').length, 1);
});
