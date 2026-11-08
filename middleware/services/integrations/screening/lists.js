// OFAC/UN/EU list fallback (PR-090): baseline substring matcher over an
// env-configured CSV. Heuristic only — a hit is POTENTIAL_MATCH for a human,
// never a verdict. Missing/unreadable file = no opinion (null), so the
// caller falls through to MANUAL_REVIEW. Reviewed matches live in COBOL.
import { readFileSync } from 'node:fs';

const norm = (s) =>
  String(s ?? '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^a-z ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

export function matchLists(name, { path = process.env.SCREENING_LISTS_PATH } = {}) {
  const q = norm(name);
  if (!q || !path) return null;
  let text;
  try {
    text = readFileSync(path, 'utf8');
  } catch {
    return null;
  }
  const parts = q.split(' ').filter((w) => w.length > 2);
  if (!parts.length) return null;
  let lineno = 0;
  for (const line of text.split('\n')) {
    lineno += 1;
    const row = norm(line);
    if (!row) continue;
    // Hit when every significant query word appears in the row, or the row's
    // core appears in the query (catches " DOE, JOHN" style entries).
    if (parts.every((w) => row.includes(w))) {
      return { result: 'POTENTIAL_MATCH', score: 0.5, ref: `lists:${lineno}` };
    }
  }
  return { result: 'CLEAR', score: 0, ref: null };
}
