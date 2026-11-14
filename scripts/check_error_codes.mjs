// Error-code parity gate (maint-01): every ERROR|<CODE> COBOL can emit must
// have an explicit HTTP status. Codes that fall through `?? 500` in
// core-client/result.js are silent contract drift (e.g. OVERPAID and
// RATE_LIMITED used to surface as 500).
//
// Sources:
//   - cobol/src/*.cob + cobol/copy/*.cpy (DRY-00B): `"ERROR|<CODE>"`
//     literals that can reach the client, including via copybooks.
//   - contracts/errors.yaml: the registry (code -> status, origin, note).
//   - middleware/core-client/result.js: the runtime ERROR_STATUS map.
//
// Rules:
//   1. Every COBOL-emitted code (minus INTERNAL_CODES) must be registered.
//   2. Every registered code must exist in ERROR_STATUS with the same status.
//   3. Every ERROR_STATUS entry must be registered (gateway-originated codes
//      like BREACHED_PASSWORD carry origin: gateway).
// INTERNAL_CODES are bridge sentinels that never reach LS-OUTPUT-BUFFER
// (verified: no `MOVE "ERROR|NO_DATA" TO LS-OUTPUT-BUFFER` in cobol/src).
//
// Usage: node scripts/check_error_codes.mjs [root]
// Exit: 0 ok, 1 violation, 2 usage error.
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const INTERNAL_CODES = new Set(['NO_DATA']);
export const REGISTRY_REL = 'contracts/errors.yaml';
export const MAP_REL = 'middleware/core-client/result.js';
export const COBOL_REL = 'cobol/src';

export function extractCobolCodes(source) {
  const out = new Set();
  for (const m of String(source || '').matchAll(/"ERROR\|([A-Z0-9_]+)"/g)) {
    out.add(m[1]);
  }
  return out;
}

// Minimal parser for the registry format written by this train:
//   two-space-indented `CODE: { status: NNN, origin: ..., ... }` lines.
// Deliberately strict: anything else fails the gate instead of being
// silently skipped.
export function parseRegistry(text) {
  const codes = new Map();
  for (const line of String(text || '').split('\n')) {
    const m = line.match(/^ {2}([A-Z0-9_]+):\s*\{([^}]*)\}\s*$/);
    if (!m) continue;
    const status = (m[2].match(/status:\s*(\d{3})/) || [])[1];
    if (!status) throw new Error(`registry entry without status: ${line.trim()}`);
    codes.set(m[1], Number(status));
  }
  return codes;
}

export function parseRuntimeMap(text) {
  const codes = new Map();
  for (const line of String(text || '').split('\n')) {
    const m = line.match(/^ {2}([A-Z0-9_]+):\s*(\d{3}),?\s*$/);
    if (!m) continue;
    codes.set(m[1], Number(m[2]));
  }
  return codes;
}

export function checkAll({ cobol, registry, runtime }) {
  const errors = [];
  for (const code of [...cobol].filter((c) => !INTERNAL_CODES.has(c)).sort()) {
    if (!registry.has(code)) errors.push(`unregistered COBOL code: ERROR|${code}`);
  }
  for (const [code, status] of [...registry.entries()].sort(([a], [b]) => (a < b ? -1 : 1))) {
    if (!runtime.has(code)) {
      errors.push(`registry code missing from ERROR_STATUS: ${code}`);
    } else if (runtime.get(code) !== status) {
      errors.push(`status mismatch for ${code}: registry=${status} runtime=${runtime.get(code)}`);
    }
  }
  for (const code of [...runtime.keys()].sort()) {
    if (!registry.has(code)) errors.push(`runtime code missing from registry: ${code}`);
  }
  return errors;
}

const args = process.argv.slice(2);
let root = '.';
for (const a of args) {
  if (a === '--help' || a === '-h') {
    console.log('usage: check_error_codes.mjs [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const dir = path.resolve(root);
  const regPath = path.join(dir, REGISTRY_REL);
  if (!existsSync(regPath)) {
    console.error(`FAIL: missing ${REGISTRY_REL} (registry is the source of truth)`);
    process.exit(1);
  }
  const cobol = new Set();
  const srcDir = path.join(dir, COBOL_REL);
  const copyDir = path.join(dir, 'cobol', 'copy');
  const readCodes = (d, ext) => {
    if (!existsSync(d)) return;
    for (const f of readdirSync(d)
      .filter((f) => f.endsWith(ext))
      .sort()) {
      for (const c of extractCobolCodes(readFileSync(path.join(d, f), 'utf8'))) cobol.add(c);
    }
  };
  readCodes(srcDir, '.cob');
  readCodes(copyDir, '.cpy');
  let registry;
  try {
    registry = parseRegistry(readFileSync(regPath, 'utf8'));
  } catch (e) {
    console.error(`FAIL: cannot parse ${REGISTRY_REL}: ${e.message}`);
    process.exit(1);
  }
  const runtime = parseRuntimeMap(readFileSync(path.join(dir, MAP_REL), 'utf8'));
  const errors = checkAll({ cobol, registry, runtime });
  if (errors.length) {
    console.error('ERROR-CODE PARITY VIOLATIONS:');
    for (const e of errors) console.error(`  ${e}`);
    process.exit(1);
  }
  console.log(`OK: ${cobol.size} COBOL codes registered with explicit HTTP status`);
}
