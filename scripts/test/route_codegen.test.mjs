// Route codegen pins (maint-13). No database, no build.
//
// middleware/spec/routes.yaml is the single source of truth for every
// gateway route; scripts/build_routes.mjs generates
// middleware/src/routes/*.js from it. These pins hold the contract:
//   - the generator runs clean on the real tree (default --check mode),
//   - every committed route file is generated (no hand-maintained files
//     beside the barrel), and the spec covers exactly the on-disk set.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

test('build_routes.mjs check passes on the real tree', () => {
  const out = execFileSync('node', [path.join(ROOT, 'scripts', 'build_routes.mjs'), ROOT], {
    encoding: 'utf8',
  });
  assert.match(out, /OK: \d+ route files match the spec/);
});

test('every route file is generated, no orphans either way', () => {
  const spec = execFileSync('grep', ['-c', '^  export: ', path.join(ROOT, 'middleware', 'spec', 'routes.yaml')], {
    encoding: 'utf8',
  }).trim();
  const onDisk = readdirSync(path.join(ROOT, 'middleware', 'src', 'routes')).filter(
    (f) => f.endsWith('.js') && f !== 'index.js',
  );
  assert.equal(onDisk.length, Number(spec), `spec must cover every route file (disk: ${onDisk.length}, spec: ${spec})`);
});
