// Unit tests for scripts/retire_modules.mjs pure helpers. No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import {
  rewriteDispatch,
  pruneBarrel,
  removeBuildSources,
  removeDbResetBlock,
  dropBaselineLines,
  pruneTokenIdentityMap,
  dropDeadActionEntries,
  dropStaleShadowedRoutes,
} from '../retire_modules.mjs';

const DISPATCH = [
  '            MOVE "AAA_" TO D-PREFIX(1).',
  '            MOVE 4 TO D-PREFIX-LEN(1).',
  '            MOVE "aaa_core" TO D-PROGRAM(1).',
  '            MOVE "BBB_" TO D-PREFIX(2).',
  '            MOVE 4 TO D-PREFIX-LEN(2).',
  '            MOVE "bbb_core" TO D-PROGRAM(2).',
  '            MOVE "CCC_" TO D-PREFIX(3).',
  '            MOVE 4 TO D-PREFIX-LEN(3).',
  '            MOVE "ccc_core" TO D-PROGRAM(3).',
  '            MOVE 3 TO DISPATCH-COUNT.',
  '',
].join('\n');

test('rewriteDispatch drops retired programs and renumbers', () => {
  const { text, removed, remaining } = rewriteDispatch(DISPATCH, new Set(['bbb_core']));
  assert.equal(removed, 1);
  assert.equal(remaining, 2);
  assert.ok(!text.includes('bbb_core'), 'retired program gone');
  assert.ok(!text.includes('BBB_'), 'retired prefix gone');
  assert.ok(text.includes('MOVE "AAA_" TO D-PREFIX(1).'), 'first slot kept');
  assert.ok(text.includes('MOVE "ccc_core" TO D-PROGRAM(2).'), 'third slot renumbered to 2');
  assert.ok(text.includes('MOVE 2 TO DISPATCH-COUNT.'), 'count updated');
  assert.ok(!text.includes('D-PREFIX(3)'), 'no stale slot numbers');
});

test('rewriteDispatch throws when nothing matches', () => {
  assert.throws(() => rewriteDispatch(DISPATCH, new Set(['zzz_core'])), /no dispatch slots matched/);
});

test('rewriteDispatch throws on unparsable input', () => {
  assert.throws(() => rewriteDispatch('no slots here\n', new Set(['bbb_core'])), /no dispatch slots parsed/);
});

test('pruneBarrel removes import and spread lines only', () => {
  const src = [
    "import { AAA_ROUTES } from './aaa.js';",
    "import { BBB_ROUTES } from './bbb.js';",
    'export const ALL_ROUTES = [',
    '  ...AAA_ROUTES,',
    '  ...BBB_ROUTES,',
    '];',
    '',
  ].join('\n');
  const out = pruneBarrel(src, ['aaa.js']);
  assert.ok(!out.includes('aaa.js'), 'import gone');
  assert.ok(!out.includes('...AAA_ROUTES'), 'spread gone');
  assert.ok(out.includes("import { BBB_ROUTES } from './bbb.js';"), 'kept import stays');
  assert.ok(out.includes('  ...BBB_ROUTES,'), 'kept spread stays');
});

test('pruneBarrel handles aliased imports without touching kept twins', () => {
  const src = [
    "import { CLM_ROUTES } from './collateral_mgmt.js';",
    "import { CLM_ROUTES as CLAIMS_ROUTES } from './claims_management.js';",
    'export const ALL_ROUTES = [',
    '  ...CLM_ROUTES,',
    '  ...CLAIMS_ROUTES,',
    '];',
    '',
  ].join('\n');
  const out = pruneBarrel(src, ['claims_management.js']);
  assert.ok(!out.includes('claims_management.js'), 'deleted import gone');
  assert.ok(!out.includes('...CLAIMS_ROUTES'), 'deleted spread gone');
  assert.ok(out.includes("import { CLM_ROUTES } from './collateral_mgmt.js';"), 'kept twin import stays');
  assert.ok(out.includes('  ...CLM_ROUTES,'), 'kept twin spread stays');
});

test('removeBuildSources removes exact source lines', () => {
  const src = [
    '    cobol/src/aaa_core.cob \\',
    '    cobol/src/aaab_core.cob \\',
    '    cobol/src/main_logic.cob \\',
    '',
  ].join('\n');
  const out = removeBuildSources(src, ['aaa_core.cob']);
  assert.ok(!out.includes('aaa_core.cob \\\n'), 'target line gone');
  assert.ok(out.includes('aaab_core.cob'), 'prefix-collision file stays');
});

test('removeDbResetBlock removes only unreferenced helpers', () => {
  const src = [
    'db_reset_aaa() {',
    '    db_exec "DELETE FROM aaa;"',
    '}',
    '',
    'db_reset_bbb() {',
    '    db_exec "DELETE FROM bbb;"',
    '}',
    '',
  ].join('\n');
  const gone = removeDbResetBlock(src, 'aaa', false);
  assert.equal(gone.removed, true);
  assert.ok(!gone.text.includes('db_reset_aaa'), 'block gone');
  assert.ok(gone.text.includes('db_reset_bbb'), 'other block stays');
  const kept = removeDbResetBlock(src, 'aaa', true);
  assert.equal(kept.removed, false);
  assert.equal(kept.text, src);
  const missing = removeDbResetBlock(src, 'zzz', false);
  assert.equal(missing.removed, false);
});

test('dropBaselineLines keeps comments and blanks', () => {
  const src = ['# header', '', 'aaa_tests=13', 'bbb_tests=7', ''].join('\n');
  const out = dropBaselineLines(src, (t) => t.split('=')[0] === 'aaa_tests');
  assert.ok(out.includes('# header'), 'comment kept');
  assert.ok(out.includes('bbb_tests=7'), 'other entry kept');
  assert.ok(!out.includes('aaa_tests'), 'target dropped');
});

test('pruneTokenIdentityMap removes only deleted actions', () => {
  const src = ['const M = {', "  AAA_CREATE: 'actor',", "  KEEP_THIS: 'actor',", "  AAAX: 'actor',", '};', ''].join(
    '\n',
  );
  const { text, removed } = pruneTokenIdentityMap(src, new Set(['AAA_CREATE']));
  assert.equal(removed, 1);
  assert.ok(!text.includes('AAA_CREATE'), 'deleted action gone');
  assert.ok(text.includes('KEEP_THIS'), 'kept action stays');
  assert.ok(text.includes('AAAX'), 'prefix-collision key stays');
});

test('dropDeadActionEntries removes deleted and unrouted actions only', () => {
  const d = mkdtempSync(path.join(tmpdir(), 'retire-base-'));
  try {
    const routes = path.join(d, 'middleware', 'src', 'routes');
    mkdirSync(routes, { recursive: true });
    writeFileSync(
      path.join(routes, 'keep.js'),
      "export const K = [\n  { method: 'get', path: '/keep', action: 'KEEP_GET', fields: [] },\n];\n",
    );
    writeFileSync(path.join(routes, 'index.js'), 'export const ALL_ROUTES = [];\n');
    writeFileSync(path.join(d, 'middleware', 'src', 'app.js'), 'export const ROUTES = [];\n');
    mkdirSync(path.join(d, 'tests'), { recursive: true });
    writeFileSync(path.join(d, 'tests', 'action_test_coverage_baseline.txt'), '# header\n\nGONE_ACTION\nKEEP_GET\n');
    const changed = dropDeadActionEntries(d, new Set(['GONE_ACTION']));
    assert.equal(changed, true);
    const out = readFileSync(path.join(d, 'tests', 'action_test_coverage_baseline.txt'), 'utf8');
    assert.ok(!out.includes('GONE_ACTION'), 'dead entry dropped');
    assert.ok(out.includes('KEEP_GET'), 'routed entry kept');
    assert.ok(out.includes('# header'), 'comment kept');
    assert.equal(dropDeadActionEntries(d, new Set(['GONE_ACTION'])), false);
  } finally {
    rmSync(d, { recursive: true, force: true });
  }
});

test('dropStaleShadowedRoutes drops only fully-gone routes', () => {
  const d = mkdtempSync(path.join(tmpdir(), 'retire-shadow-'));
  try {
    const routes = path.join(d, 'middleware', 'src', 'routes');
    mkdirSync(routes, { recursive: true });
    writeFileSync(
      path.join(routes, 'keep.js'),
      "export const K = [\n  { method: 'get', path: '/keep', action: 'KEEP_GET', fields: [] },\n];\n",
    );
    writeFileSync(path.join(routes, 'index.js'), 'export const ALL_ROUTES = [];\n');
    writeFileSync(path.join(d, 'middleware', 'src', 'app.js'), 'export const ROUTES = [];\n');
    mkdirSync(path.join(d, 'tests'), { recursive: true });
    writeFileSync(path.join(d, 'tests', 'known_shadowed_routes.txt'), '# header\n\nGET /gone\nGET /keep\n');
    const changed = dropStaleShadowedRoutes(d);
    assert.equal(changed, true);
    const out = readFileSync(path.join(d, 'tests', 'known_shadowed_routes.txt'), 'utf8');
    assert.ok(!out.includes('GET /gone'), 'gone route dropped');
    assert.ok(out.includes('GET /keep'), 'live route kept even though single');
  } finally {
    rmSync(d, { recursive: true, force: true });
  }
});
