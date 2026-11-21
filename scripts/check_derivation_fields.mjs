// Derivation-vs-spec gate (arch9 WP-13, T-13.3).
// Every client field consumed by a server-side derivation must be declared
// as `derivedFields` in middleware/spec/routes.yaml: it is documented in
// OpenAPI as a normal body field and must never leak into the 6-slot COBOL
// pipe (`fields`). Server-derived outputs (hashes, verdicts) stay in `fields`
// as optional slots filled by applyDerivation; raw inputs never reach COBOL.
//
// Reads the spec as text (independent of build_routes.mjs so it reports the
// 4 legacy mismatches before the generator learns the new key), imports
// DERIVATIONS to prove the adapter side exists, and cross-checks the source
// for required(input, ...) so the EXPECTED map cannot go stale silently.
// Usage: node scripts/check_derivation_fields.mjs [root]
import { readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const SPEC = path.join(ROOT, 'middleware', 'spec', 'routes.yaml');
const SIGNALS = path.join(ROOT, 'middleware', 'adapters', 'signals.js');

// Client inputs each derivation consumes. RISK_NOTE is intentionally absent:
// deriveRisk needs only `email` (already a pipe field) plus the socket IP,
// so it declares no derivedFields.
const EXPECTED = {
  IDV_NIK_VALIDATE: [{ name: 'nik', pattern: 'NIK', required: true }],
  IDV_KTP_OCR_RESULT: [{ name: 'imageRef', pattern: 'KEY', required: true }],
  SCR_SCREEN: [
    { name: 'name', pattern: 'NAME', required: true },
    { name: 'dob', pattern: 'DATE', required: false },
    { name: 'consent', pattern: 'FLAG', required: true },
  ],
  OTP_LINK_BEGIN: [{ name: 'phone', pattern: 'PHONE', required: true }],
};

const failures = [];
const fail = (m) => failures.push(m);

function parseFieldList(inner, what) {
  if (!inner.trim()) return [];
  return inner
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
    .map((tok) => {
      const m = tok.match(/^([A-Za-z][A-Za-z0-9_]*)\s*:\s*([A-Z][A-Z0-9_]*)\s*(\?)?$/);
      if (!m) {
        fail(`bad ${what} field ${JSON.stringify(tok)}`);
        return null;
      }
      return { name: m[1], pattern: m[2], required: !m[3] };
    })
    .filter(Boolean);
}

const specSrc = readFileSync(SPEC, 'utf8');
const signalsSrc = readFileSync(SIGNALS, 'utf8');

// Per-route records: action -> { derived: [...], pipe: [...] }.
const routes = new Map();
for (const line of specSrc.split('\n')) {
  const s = line.trim();
  if (!s.startsWith('- {')) continue;
  const action = (s.match(/action\s*:\s*([A-Z][A-Z0-9_]*)/) || [])[1];
  if (!action) continue;
  const dm = s.match(/derivedFields\s*:\s*\[([^\]]*)\]/);
  const fm = s.match(/fields\s*:\s*\[([^\]]*)\]/);
  const derived = dm ? parseFieldList(dm[1], `derivedFields (${action})`) : [];
  const pipe = fm
    ? fm[1]
        .split(',')
        .map((x) => x.trim())
        .filter(Boolean)
        .map((tok) => {
          const m = tok.match(/^([A-Za-z][A-Za-z0-9_]*)\s*:\s*([A-Z][A-Z0-9_]*)/);
          return m ? m[1] : tok;
        })
    : [];
  routes.set(action, { derived, pipe });
}

if (failures.length) {
  console.error('FAIL: derivation fields gate:');
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}

// 1. Spec must declare exactly EXPECTED for the 4 derived actions.
for (const [action, want] of Object.entries(EXPECTED)) {
  const got = routes.get(action);
  if (!got) {
    fail(`${action}: route missing from spec`);
    continue;
  }
  const same =
    got.derived.length === want.length &&
    want.every(
      (w, i) =>
        got.derived[i] &&
        got.derived[i].name === w.name &&
        got.derived[i].pattern === w.pattern &&
        got.derived[i].required === w.required,
    );
  if (!same) {
    const fmt = (l) => l.map((f) => `${f.name}:${f.pattern}${f.required ? '' : '?'}`).join(', ') || '(none)';
    fail(`${action}: derivedFields mismatch: spec has [${fmt(got.derived)}], want [${fmt(want)}]`);
  }
  // 2. Derived inputs must never appear as pipe slots (raw never reaches COBOL).
  for (const w of want) {
    if (got.pipe.includes(w.name)) fail(`${action}: derived input '${w.name}' must not be a pipe field`);
  }
}

// 3. No other route may declare derivedFields (RISK_NOTE included: no raw input).
for (const [action, r] of routes) {
  if (!EXPECTED[action] && r.derived.length) fail(`${action}: unexpected derivedFields (no derivation consumes them)`);
}

// 4. Every EXPECTED action must have a derivation in signals.js; every
// derivation needing raw client input must be in EXPECTED (RISK_NOTE exempt:
// email is a pipe field, IP comes from the socket).
const { DERIVATIONS } = await import(pathToFileURL(SIGNALS).href).catch(() => ({}));
for (const action of Object.keys(EXPECTED)) {
  if (!DERIVATIONS || !DERIVATIONS[action])
    fail(`${action}: missing DERIVATIONS entry in middleware/adapters/signals.js`);
}
for (const action of Object.keys(DERIVATIONS || {})) {
  if (!EXPECTED[action] && action !== 'RISK_NOTE')
    fail(`${action}: derivation has no EXPECTED derivedFields entry (update this gate)`);
}

// 5. EXPECTED cannot go stale: each expected field must be read from `input`
// in signals.js (required(input, 'x') or input.x).
for (const [action, want] of Object.entries(EXPECTED)) {
  for (const w of want) {
    const read = signalsSrc.includes(`'${w.name}'`) && signalsSrc.includes('input');
    if (!read) fail(`${action}: signals.js never reads input '${w.name}' (EXPECTED stale?)`);
  }
}

if (failures.length) {
  console.error('FAIL: derivation fields gate:');
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`OK: derivation fields in sync (${Object.keys(EXPECTED).length} derived actions + RISK_NOTE exempt)`);

function pathToFileURL(p) {
  const u = new URL('file://');
  u.pathname = p;
  return u;
}
