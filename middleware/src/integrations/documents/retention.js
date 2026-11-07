// Retention policy (PR-096): pure decisions on object age and verification
// state. Delete after OCR/verification + N days; legal hold always wins;
// infected objects are eligible immediately (no retention for malware).
export function retentionDue({
  storedAt,
  verifiedAt = null,
  retentionDays = Number(process.env.VAULT_RETENTION_DAYS || 30),
  legalHold = false,
  infected = false,
  now = Date.now(),
} = {}) {
  if (legalHold) return { due: false, reason: 'legal-hold' };
  if (infected) return { due: true, reason: 'infected' };
  const anchor = verifiedAt ?? storedAt;
  if (!anchor) return { due: false, reason: 'no-anchor' };
  const ageDays = (now - new Date(anchor).getTime()) / 86400000;
  if (Number.isNaN(ageDays)) return { due: false, reason: 'bad-date' };
  return ageDays > retentionDays ? { due: true, reason: 'expired' } : { due: false, reason: 'retained' };
}

// Retention sweep (gap-closure #4): apply the policy to a batch of stored
// objects and delete exactly the due set. The deleter is injected so the
// scale drill runs against a fake; production passes deleteObject.
// Deletions are audited with key + hash only (never bytes). One object's
// delete failure is reported per key and never stops the sweep.
export async function sweepRetention(objects, { deleteOne, logger = null, retentionDays, now = Date.now() } = {}) {
  if (typeof deleteOne !== 'function') throw new Error('sweepRetention needs a deleteOne(key) function');
  const summary = { checked: 0, deleted: [], kept: [], failed: [] };
  for (const obj of objects || []) {
    summary.checked += 1;
    const verdict = retentionDue({
      storedAt: obj.storedAt,
      verifiedAt: obj.verifiedAt ?? null,
      ...(retentionDays === undefined ? {} : { retentionDays }),
      legalHold: !!obj.legalHold,
      infected: !!obj.infected,
      now,
    });
    if (!verdict.due) {
      summary.kept.push({ key: obj.key, reason: verdict.reason });
      continue;
    }
    try {
      await deleteOne(obj.key);
      summary.deleted.push({ key: obj.key, reason: verdict.reason });
      if (logger)
        logger({ event: 'retention_deleted', key: obj.key, sha256: obj.sha256 || null, reason: verdict.reason });
    } catch (err) {
      summary.failed.push({ key: obj.key, message: (err && err.message) || String(err) });
      if (logger)
        logger({ event: 'retention_delete_failed', key: obj.key, message: (err && err.message) || String(err) });
    }
  }
  return summary;
}
