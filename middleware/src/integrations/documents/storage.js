// S3-compatible document vault (PR-096): MinIO self-host via raw REST with
// SigV4 (no SDK dependency). Bucket private; object keys randomized;
// callers store key + sha256 + kms_key_id (never image bytes in MySQL).
// SSE-KMS headers ride every PUT when VAULT_KMS_KEY_ID is set.
import { createHash, createHmac } from 'node:crypto';
import { randomBytes } from 'node:crypto';
import { resilientFetch, DEFAULT_TIMEOUT_MS } from '../resilience.js';

export const MAX_OBJECT_BYTES = 5 * 1024 * 1024;
const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'application/pdf']);

export function vaultConfig() {
  return {
    endpoint: process.env.VAULT_ENDPOINT || '',
    bucket: process.env.VAULT_BUCKET || 'documents',
    region: process.env.VAULT_REGION || 'us-east-1',
    accessKey: process.env.VAULT_ACCESS_KEY || '',
    secretKey: process.env.VAULT_SECRET_KEY || '',
    kmsKeyId: process.env.VAULT_KMS_KEY_ID || '',
  };
}

export function assertObjectAllowed({ bytes, mime }) {
  if (!bytes || bytes.length > MAX_OBJECT_BYTES) return { ok: false, reason: 'oversize (5 MB max)' };
  if (!ALLOWED_MIME.has(mime)) return { ok: false, reason: 'unsupported type (JPEG/PNG/PDF)' };
  return { ok: true };
}

export function objectKey(prefix = 'ktp') {
  return `${prefix}/${Date.now().toString(36)}-${randomBytes(8).toString('hex')}`;
}

export function sha256Hex(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function hmacHex(key, data) {
  return createHmac('sha256', key).update(data).digest();
}

function amzDate() {
  const d = new Date();
  const stamp = d.toISOString().replace(/[-:.]/g, '').slice(0, 15) + 'Z';
  return { stamp, date: stamp.slice(0, 8) };
}

// Minimal SigV4 for PUT/GET/DELETE (unsigned payload).
export function signRequest({ method, url, region, accessKey, secretKey, mime = '', extraHeaders = {} }) {
  const u = new URL(url);
  const { stamp, date } = amzDate();
  const headers = { host: u.host, 'x-amz-content-sha256': 'UNSIGNED-PAYLOAD', 'x-amz-date': stamp, ...extraHeaders };
  if (mime) headers['content-type'] = mime;
  const names = Object.keys(headers).sort();
  const canonical = [
    method,
    u.pathname + (u.search ? u.search.replace(/^\?/, '?') : ''),
    names.map((n) => `${n}:${String(headers[n]).trim()}`).join('\n') + '\n',
    names.join(';'),
    'UNSIGNED-PAYLOAD',
  ].join('\n');
  const scope = `${date}/${region}/s3/aws4_request`;
  const toSign = ['AWS4-HMAC-SHA256', stamp, scope, createHash('sha256').update(canonical).digest('hex')].join('\n');
  const kDate = hmacHex(`AWS4${secretKey}`, date);
  const kRegion = hmacHex(kDate, region);
  const kService = hmacHex(kRegion, 's3');
  const kSigning = hmacHex(kService, 'aws4_request');
  const signature = createHmac('sha256', kSigning).update(toSign).digest('hex');
  return {
    ...headers,
    Authorization: `AWS4-HMAC-SHA256 Credential=${accessKey}/${scope}, SignedHeaders=${names.join(';')}, Signature=${signature}`,
  };
}

export async function putObject(
  { key, bytes, mime },
  {
    fetchImpl = fetch,
    timeoutMs = Number(process.env.VAULT_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
    cfg = vaultConfig(),
  } = {},
) {
  const gate = assertObjectAllowed({ bytes, mime });
  if (!gate.ok) throw new Error(`vault refused: ${gate.reason}`);
  if (!cfg.endpoint || !cfg.accessKey) throw new Error('VAULT_ENDPOINT/VAULT_ACCESS_KEY are not set');
  const url = `${cfg.endpoint}/${cfg.bucket}/${key}`;
  const extra = cfg.kmsKeyId
    ? { 'x-amz-server-side-encryption': 'aws:kms', 'x-amz-server-side-encryption-aws-kms-key-id': cfg.kmsKeyId }
    : {};
  const headers = signRequest({
    method: 'PUT',
    url,
    region: cfg.region,
    accessKey: cfg.accessKey,
    secretKey: cfg.secretKey,
    mime,
    extraHeaders: extra,
  });
  const res = await resilientFetch('minio', url, { method: 'PUT', headers, body: bytes }, { fetchImpl, timeoutMs });
  if (!res.ok) throw new Error(`vault store failed: HTTP ${res.status}`);
  return { key, sha256: sha256Hex(bytes), kmsKeyId: cfg.kmsKeyId || null };
}

export async function deleteObject(
  key,
  {
    fetchImpl = fetch,
    timeoutMs = Number(process.env.VAULT_TIMEOUT_MS || DEFAULT_TIMEOUT_MS),
    cfg = vaultConfig(),
  } = {},
) {
  if (!cfg.endpoint || !cfg.accessKey) throw new Error('VAULT_ENDPOINT/VAULT_ACCESS_KEY are not set');
  const url = `${cfg.endpoint}/${cfg.bucket}/${key}`;
  const headers = signRequest({
    method: 'DELETE',
    url,
    region: cfg.region,
    accessKey: cfg.accessKey,
    secretKey: cfg.secretKey,
  });
  const res = await resilientFetch('minio', url, { method: 'DELETE', headers }, { fetchImpl, timeoutMs });
  if (!res.ok && res.status !== 404) throw new Error(`vault delete failed: HTTP ${res.status}`);
  return true;
}
