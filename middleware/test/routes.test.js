// Guard: admin actions must authorize from the verified token, not the request
// body - otherwise a caller can impersonate a SUPER_ADMIN with a body `actor`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ROUTES } from '../src/app.js';

const ADMIN_ACTIONS = ['CHANGE_ROLE', 'RECONCILE'];

test('every admin action route takes its actor from the token', () => {
  for (const action of ADMIN_ACTIONS) {
    const routes = ROUTES.filter((r) => r.action === action);
    assert.ok(routes.length > 0, `${action} is exposed by a route`);
    for (const route of routes) {
      assert.equal(route.actorFromToken, true, `${route.method} ${route.path} (${action}) must set actorFromToken`);
    }
  }
});
