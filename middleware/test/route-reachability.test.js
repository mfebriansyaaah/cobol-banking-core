// Route reachability: every registered route must answer with a routed
// status, never 404/405/5xx. Guarded routes are hit WITHOUT a token, so
// requireAuth rejects them (401/403) before any COBOL runs: this proves the
// method+path is registered without executing anything. Public routes (auth
// endpoints, all with required fields) are hit with an empty body, so field
// validation rejects them (400) before any COBOL runs. No request in this
// file can write: nothing here carries a token or passes validation.
//
// A 200/400 from a guarded route would mean auth was skipped; a 401/403 from
// a public route would mean auth was wrongly added; both fail the suite.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { buildApp, ROUTES } from '../src/app.js';

const app = buildApp();

// Express parameters (/:id, /:email, ...) become a harmless literal.
const fillParams = (p) => p.replace(/:[^/]+/g, '1');

test('every registered route responds (never 404/405/5xx)', async () => {
  const failures = [];
  for (const route of ROUTES) {
    // Probe routes answer 503 without a database; the dedicated probe test
    // below covers them (here they would false-fail the generic contract).
    if (route.custom === 'health' || route.custom === 'ready') continue;
    const path = fillParams(route.path);
    let res;
    try {
      const r = request(app)[route.method](path);
      if (route.method === 'post' || route.method === 'put' || route.method === 'patch') {
        res = await r.send({});
      } else {
        res = await r;
      }
    } catch (err) {
      failures.push(`${route.method.toUpperCase()} ${route.path} (${route.action}): threw ${err && err.message}`);
      continue;
    }
    const tag = `${route.method.toUpperCase()} ${route.path} (${route.action})`;
    if (res.status === 404 || res.status === 405 || res.status >= 500) {
      failures.push(`${tag}: HTTP ${res.status} (unregistered or crashed)`);
      continue;
    }
    if (route.public) {
      // Credential-bearing public routes (refresh/logout take a refresh
      // token, not fields) answer 401 on an empty body instead of 400.
      const ok =
        route.custom === 'refresh' || route.custom === 'logout'
          ? [200, 400, 401, 409, 422].includes(res.status)
          : [200, 400, 409, 422].includes(res.status);
      if (!ok) {
        failures.push(
          `${tag}: public route returned HTTP ${res.status}, expected validation/success (2xx/400/409/422)`,
        );
      }
    } else if (![401, 403].includes(res.status)) {
      failures.push(`${tag}: guarded route returned HTTP ${res.status} without a token, expected 401/403`);
    }
  }
  assert.deepEqual(
    failures.slice(0, 30),
    [],
    `${failures.length} of ${ROUTES.length} routes unreachable or misguarded`,
  );
});

test('health and readiness probes answer', async () => {
  assert.equal((await request(app).get('/health')).status, 200);
  // 503 means the route exists but the database is down; either way it is
  // registered (the point of this suite).
  assert.ok([200, 503].includes((await request(app).get('/ready')).status));
});
