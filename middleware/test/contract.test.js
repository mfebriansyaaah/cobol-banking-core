import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync } from 'node:fs';
import path from 'node:path';

const dir = path.resolve('src/routes');
const files = readdirSync(dir).filter((f) => f.endsWith('.js') && f !== 'index.js');

for (const file of files) {
  test(`contract: ${file} exports a route array`, async () => {
    const mod = await import(path.join(dir, file));
    const exportName = Object.keys(mod).find((k) => k.endsWith('_ROUTES'));
    assert.ok(exportName, `${file} must export *_ROUTES`);
    const routes = mod[exportName];
    assert.ok(Array.isArray(routes), `${exportName} must be an array`);
    for (const r of routes) {
      assert.ok(['get', 'post', 'put', 'patch', 'delete'].includes(r.method), `invalid method in ${file}`);
      assert.ok(typeof r.path === 'string' && r.path.startsWith('/'), `invalid path in ${file}`);
      if (r.custom) {
        // Infrastructure routes (routes/infra.js) carry bespoke handlers, not
        // COBOL actions: only the custom key is required.
        assert.ok(typeof r.custom === 'string' && r.custom.length > 0, `invalid custom in ${file}`);
        continue;
      }
      assert.ok(typeof r.action === 'string' && r.action.length > 0, `invalid action in ${file}`);
      assert.ok(Array.isArray(r.fields) && r.fields.length === 6, `fields must have 6 slots in ${file}`);
    }
  });
}
