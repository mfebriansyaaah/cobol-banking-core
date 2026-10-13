// Guard: unknown or missing actor identity must be enforced in COBOL for both
// admin actions and per-user reads, and a route must never take the actor from
// the request body. Routes whose COBOL action authorizes by actor must set
// actorFromToken.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ROUTES } from '../src/app.js';

// Admin-only actions plus per-user reads that are self-or-admin.
const ACTOR_ACTIONS = ['CHANGE_ROLE', 'RECONCILE', 'GET_USER', 'CHECK_BALANCE', 'GET_DASHBOARD', 'LIST_USERS'];

test('every actor-authorized action takes its actor from the token', () => {
  for (const action of ACTOR_ACTIONS) {
    const routes = ROUTES.filter((r) => r.action === action);
    assert.ok(routes.length > 0, `${action} is exposed by a route`);
    for (const route of routes) {
      assert.equal(route.actorFromToken, true, `${route.method} ${route.path} (${action}) must set actorFromToken`);
    }
  }
});
