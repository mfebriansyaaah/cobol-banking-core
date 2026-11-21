// WP-13 pins: derivedFields flow from spec → routes → registry → OpenAPI
// without ever entering the COBOL pipe. No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

test('spec declares derivedFields for the 4 derived actions only', async () => {
  const { parseSpec } = await import('../build_routes.mjs');
  const files = parseSpec(ROOT);
  const byAction = new Map();
  for (const f of files) for (const r of f.routes) byAction.set(r.action, r);
  const want = {
    IDV_NIK_VALIDATE: [{ name: 'nik', pattern: 'NIK', required: true }],
    IDV_KTP_OCR_RESULT: [{ name: 'imageRef', pattern: 'KEY', required: true }],
    SCR_SCREEN: [
      { name: 'name', pattern: 'NAME', required: true },
      { name: 'dob', pattern: 'DATE', required: false },
      { name: 'consent', pattern: 'FLAG', required: true },
    ],
    OTP_LINK_BEGIN: [{ name: 'phone', pattern: 'PHONE', required: true }],
  };
  for (const [action, fields] of Object.entries(want)) {
    assert.deepEqual(byAction.get(action).derivedFields, fields, `${action} derivedFields`);
  }
  for (const [action, r] of byAction) {
    if (!want[action])
      assert.ok(!r.derivedFields || !r.derivedFields.length, `${action} must not declare derivedFields`);
  }
});

test('derived inputs never enter the COBOL pipe', async () => {
  const { collectRouteContracts } = await import('../lib/contract.mjs');
  const actions = collectRouteContracts(ROOT);
  const derived = actions.filter((a) => a.derivedFields && a.derivedFields.length);
  assert.equal(derived.length, 4);
  for (const a of derived) {
    const pipeNames = new Set(a.fields.map((f) => f.name).filter(Boolean));
    for (const d of a.derivedFields) {
      assert.ok(!pipeNames.has(d.name), `${a.action}: derived '${d.name}' must not be a pipe field`);
      assert.ok(d.pattern, `${a.action}: derived '${d.name}' needs a pattern`);
    }
  }
});

test('registry round-trips derivedFields and openapi documents them', async () => {
  const { loadContract, collectRouteContracts } = await import('../lib/contract.mjs');
  const live = collectRouteContracts(ROOT).filter((a) => a.derivedFields);
  const file = loadContract(ROOT).filter((a) => a.derivedFields && a.derivedFields.length);
  assert.equal(file.length, live.length);
  assert.deepEqual(
    file.map((e) => e.derivedFields),
    live.map((e) => e.derivedFields),
  );
  const openapi = readFileSync(path.join(ROOT, 'docs', 'openapi.yaml'), 'utf8');
  for (const needle of ['nik:', 'imageRef:', 'consent:'])
    assert.ok(openapi.includes(needle), `openapi must document ${needle}`);
});

test('derivation gate passes on the real tree', () => {
  const out = execFileSync('node', [path.join(ROOT, 'scripts', 'check_derivation_fields.mjs'), ROOT], {
    encoding: 'utf8',
  });
  assert.match(out, /OK: derivation fields in sync/);
});
