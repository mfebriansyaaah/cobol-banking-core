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
const shape = (path) => segments(path).map((s) => (isParam(s) ? ':param' : s)).join('/');

function matchesEarlier(earlierPath, laterPath) {
  const a = segments(earlierPath);
  const b = segments(laterPath);
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i += 1) {
    if (isParam(a[i])) continue;
    if (a[i] !== b[i]) return false;
  }
  return true;
}

test('static routes are not shadowed by earlier parameterized routes', () => {
  const seen = [];
  const failures = [];

  for (const route of ROUTES) {
    for (const earlier of seen) {
      if (earlier.method !== route.method) continue;
      const sameShape = shape(earlier.path) === shape(route.path);
      if (sameShape && earlier.path !== route.path) {
        failures.push(`${route.method.toUpperCase()} ${route.path} shares a shape with earlier ${earlier.path}`);
      } else if (!sameShape && matchesEarlier(earlier.path, route.path)) {
        failures.push(`${route.method.toUpperCase()} ${route.path} is shadowed by earlier ${earlier.path}`);
      }
    }
    seen.push(route);
  }

  assert.deepEqual(failures, [], `route shadowing detected:\n${failures.join('\n')}`);
});
