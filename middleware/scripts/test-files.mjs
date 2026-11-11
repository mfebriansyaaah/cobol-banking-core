// Single source of truth for gateway test file groups (maint-02).
//
// middleware/package.json had the same 36 file paths copy-pasted across 11
// npm scripts; adding one test file meant editing every script, and a miss
// silently dropped the file from a suite. npm scripts now call
// `node scripts/test-files.mjs <group>` (cwd = middleware/) instead.
//
// Groups compose from shared lists so a new file is added once:
//   unit       15 files, no DB/binary needed
//   fastExtra  19 files, fast-only (integrations, IPC, pool, mount, ...)
//   dbExtra     5 files, DB-backed, serial order matters (kept exact)
//   gateway     2 files, HTTP suites (also the tail of db, order kept exact)
//   endpoints   1 file (subset of gateway)
//   fast    = unit + fastExtra          (parallel: order irrelevant)
//   full    = fast + gateway            (parallel: order irrelevant)
//   db      = dbExtra + gateway         (SERIAL: exact test:db order kept)
//   gateway = gateway, endpoints = endpoints
//
// test:junit (bare `node --test` discovery) and test:coverage are untouched.
//
// Usage: node scripts/test-files.mjs <group> [--groups]
// Exit: 0 ok, 2 usage error (unknown group).
import { pathToFileURL } from 'node:url';

const UNIT = [
  'test/contract.test.js',
  'test/field_order.test.js',
  'test/invoker.timeout.test.js',
  'test/mailer.test.js',
  'test/namespace.test.js',
  'test/pool-config.test.js',
  'test/ratelimit.test.js',
  'test/result.test.js',
  'test/route-order.test.js',
  'test/route-reachability.test.js',
  'test/routes.test.js',
  'test/security.test.js',
  'test/validation.test.js',
  'test/trust-boundary.test.js',
  'test/derivations.test.js',
];

const FAST_EXTRA = [
  'test/auth-session.test.js',
  'test/ipc_contract.test.js',
  'test/ipc_contract_pool.test.js',
  'test/integrations.test.js',
  'test/integrations/nik.test.js',
  'test/integrations/privacy.test.js',
  'test/integrations/resilience.test.js',
  'test/integrations/hardening.test.js',
  'test/integrations/screening.test.js',
  'test/integrations/fx.test.js',
  'test/integrations/geoip.test.js',
  'test/integrations/pwned.test.js',
  'test/integrations/bot.test.js',
  'test/integrations/ops.test.js',
  'test/integrations/vault.test.js',
  'test/integrations/gleif.test.js',
  'test/mount.test.js',
  'test/observability.test.js',
  'test/pool.test.js',
];

const GATEWAY = ['test/gateway.test.js', 'test/endpoints.test.js'];

const DB_EXTRA = [
  'test/auth-session.test.js',
  'test/ipc_contract.test.js',
  'test/ipc_contract_pool.test.js',
  'test/observability.test.js',
  'test/pool.test.js',
];

export const GROUPS = {
  unit: [...UNIT],
  fast: [...UNIT, ...FAST_EXTRA],
  full: [...UNIT, ...FAST_EXTRA, ...GATEWAY],
  db: [...DB_EXTRA, ...GATEWAY],
  gateway: [...GATEWAY],
  endpoints: ['test/endpoints.test.js'],
};

const args = process.argv.slice(2);
if (args.includes('--groups')) {
  console.log(Object.keys(GROUPS).join('\n'));
} else if (args.length === 1 && GROUPS[args[0]]) {
  console.log(GROUPS[args[0]].join(' '));
} else {
  console.error(`usage: test-files.mjs <group> [--groups] (groups: ${Object.keys(GROUPS).join(', ')})`);
  if (import.meta.url === pathToFileURL(process.argv[1]).href) process.exit(2);
}
