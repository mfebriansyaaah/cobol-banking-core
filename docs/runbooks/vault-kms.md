# Runbook — Vault KMS Provisioning, Rotation, and Retention Sweep

## Scope

Document images (KTP/loan) rest encrypted in MinIO via SSE-KMS. The gateway
sends `x-amz-server-side-encryption: aws:kms` plus the key id on every PUT
when `VAULT_KMS_KEY_ID` is set, and records the key id per object at write
time (`putObject` returns `kmsKeyId`; callers persist key + sha256 +
kms_key_id, never bytes). Rotation is a config change, not a re-encrypt:
old objects keep their recorded key id and stay readable.

Production requires a real KMS (env-only dev defaults in
`middleware/.env.example` and `docker-compose.test.yml` are dev-only, like
the single-node MinIO).

## No HTTP surface (by design)

Document intake has no gateway endpoint: KTP material is never persisted
and OCR runs by reference (`imageRef`), so there is nothing to upload
through the API. `putObject`/`scanBuffer`/`sweepRetention` are
operator-grade library calls exercised by the vault suite and the drill
above — not request-path code. `scripts/test/vault_surface.test.mjs`
locks this: wiring a documents adapter into `middleware/src` fails the
gate until this section is deliberately revised.

## Provisioning (once per environment)

- [ ] Create the KMS key in the environment's KMS (AWS KMS, MinIO KES, or
      equivalent); note the key id/ARN.
- [ ] Grant the vault role encrypt/decrypt on that key only (least
      privilege; no `*` key policy).
- [ ] Set `VAULT_KMS_KEY_ID` in the deployment secret store (not `.env`).
- [ ] Upload one probe object and assert the SSE-KMS response headers; the
      suite equivalent is `SigV4 signs PUT with KMS headers` plus
      `KMS key id pins at write time` in
      `middleware/test/integrations/vault.test.js`.
- [ ] Record key id, operator, and date in the change record.

## Rotation (new key version or new key)

- [ ] Provision the new key; do NOT disable the old one yet.
- [ ] Deploy with `VAULT_KMS_KEY_ID` pointing at the new key id.
- [ ] Verify: new uploads record the new id; a sample old object still
      reads (its recorded id still resolves).
- [ ] Only then schedule old-key disablement per the KMS provider's
      waiting period. There is no re-encryption step — per-object key ids
      make rotation atomic at deploy time.
- [ ] If the rotation changed production behavior, update this runbook.

## Retention sweep (operator drill)

Policy (`middleware/services/integrations/documents/retention.js`): delete after
verification + `VAULT_RETENTION_DAYS` (default 30); legal hold always wins;
infected objects go immediately; deletions audit key + hash only.

- [ ] List candidate objects (key, storedAt, verifiedAt, legalHold,
      infected, sha256) from the registry.
- [ ] Run `sweepRetention` (production passes the real `deleteObject`).
      One object's failure is reported per key and never stops the sweep.
- [ ] Confirm the summary: `checked` equals the candidate count, every
      `deleted` key was due, every legal hold is in `kept`, `failed` is
      empty or has a follow-up ticket.
- [ ] The scale evidence is `retention sweep at scale deletes exactly the
  due set` (200 mixed objects, exact delete set asserted).

## References

- `middleware/services/integrations/documents/storage.js` — PUT/DELETE, SSE-KMS
  headers, per-object key id.
- `middleware/services/integrations/documents/retention.js` — policy predicate
  and sweep.
- `docs/DATA_RETENTION.md` — policy summary and dev-only scope note.
