// Route-order guard.
//
// Express dispatches to the first matching route. A parameterized route such
// as GET /loans/:id registered before GET /loans/summary makes the static
// route unreachable even though both are present in the table. The static
// gate checks this too; this test keeps the invariant in the gateway suite so
// a route-table change fails without needing the CLI gate.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ROUTES } from '../src/app.js';

const segments = (path) => path.split('/');
const isParam = (segment) => segment.startsWith(':');
const shape = (path) =>
  segments(path)
    .map((s) => (isParam(s) ? ':param' : s))
    .join('/');

function matchesEarlier(aSegs, bSegs) {
  if (aSegs.length !== bSegs.length) return false;
  for (let i = 0; i < aSegs.length; i += 1) {
    if (isParam(aSegs[i])) continue;
    if (aSegs[i] !== bSegs[i]) return false;
  }
  return true;
}

test('static routes are not shadowed by earlier parameterized routes', () => {
  const failures = [];
  // Precompute segments/shape once. The old version recomputed split/map/join
  // per pair: O(n^2) string work over 5342 routes = 14.3M pairs, ~9s CPU.
  const prepared = ROUTES.map((r) => ({
    method: r.method,
    path: r.path,
    segs: segments(r.path),
    shape: shape(r.path),
  }));
  // Shadowing needs the same method AND segment count, so only pairs inside
  // one group can match. Same failure messages, same order, ~2 orders of
  // magnitude fewer comparisons.
  const groups = new Map();
  for (const route of prepared) {
    const key = `${route.method}|${route.segs.length}`;
    const earlier = groups.get(key) || [];
    for (const e of earlier) {
      const sameShape = e.shape === route.shape;
      if (sameShape && e.path !== route.path) {
        failures.push(`${route.method.toUpperCase()} ${route.path} shares a shape with earlier ${e.path}`);
      } else if (!sameShape && matchesEarlier(e.segs, route.segs)) {
        failures.push(`${route.method.toUpperCase()} ${route.path} is shadowed by earlier ${e.path}`);
      }
    }
    earlier.push(route);
    groups.set(key, earlier);
  }

  assert.deepEqual(failures, [], `route shadowing detected:\n${failures.join('\n')}`);
});
