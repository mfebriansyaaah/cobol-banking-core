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
