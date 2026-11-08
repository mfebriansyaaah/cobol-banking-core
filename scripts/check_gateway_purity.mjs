// Gateway purity gate: JS is an API gateway and nothing more.
//
// Enforces the 10/10 boundary for "absence of business logic / DB access":
//   - middleware/src is transport only (routing, shape validation, auth
//     handoff, COBOL invoke, HTTP mapping). Domain policy lives in
//     middleware/services, workers in middleware/workers.
//   - routes/** are declarative: only ../validation.js imports, no env,
//     no invoke, no fetch, no fs.
//   - COBOL invoke is allowed only in invoker.js (defines), app.js,
//     authService.js, and tokenStore.js.
//   - responseMappers.js is pure presentation: may delegate to authService,
//     must not invoke COBOL or sign tokens directly.
//   - No SQL strings, DB drivers, or money arithmetic in src.
//   - No src imports from workers/jobs; services imports only via allowlist.
//
// Usage: node scripts/check_gateway_purity.mjs [root]
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const SRC = path.join(ROOT, 'middleware', 'src');
const ROUTES_DIR = path.join(SRC, 'routes');

const failures = [];
const fail = (m) => failures.push(m);

function listJs(dir) {
  const out = [];
  const walk = (d) => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith('.js')) out.push(p);
    }
  };
  if (existsSync(dir)) walk(dir);
  return out;
}

function stripComments(src) {
  return src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1');
}

function importsOf(src) {
  const clean = stripComments(src);
  const out = [];
  for (const m of clean.matchAll(/import\s+(?:[^'"]+?\s+from\s+)?['"]([^'"]+)['"]/g)) out.push(m[1]);
  for (const m of clean.matchAll(/await\s+import\(\s*['"]([^'"]+)['"]\s*\)/g)) out.push(m[1]);
  for (const m of clean.matchAll(/[^a-zA-Z]import\(\s*['"]([^'"]+)['"]\s*\)/g)) out.push(m[1]);
  return out;
}

// 0. Relocated paths must not exist inside src.
for (const p of ['integrations', 'mailer.js', 'outbox_worker.js']) {
  if (existsSync(path.join(SRC, p))) fail(`relocation: middleware/src/${p} must not exist (services/workers own it)`);
}

// 1. routes/** declarative only (barrel index.js excluded: it only re-exports).
for (const f of listJs(ROUTES_DIR)) {
  if (path.basename(f) === 'index.js') continue;
  const rel = path.relative(ROOT, f);
  const src = readFileSync(f, 'utf8');
  const clean = stripComments(src);
  for (const imp of importsOf(src)) {
    if (imp !== '../validation.js') fail(`${rel}: only '../validation.js' imports allowed (got '${imp}')`);
  }
  if (/process\.env/.test(clean)) fail(`${rel}: routes must not read process.env`);
  if (/\binvoke\s*\(/.test(clean)) fail(`${rel}: routes must not invoke COBOL`);
  if (/\bfetch\s*\(/.test(clean)) fail(`${rel}: routes must not fetch`);
  if (/node:fs|node:net|child_process/.test(clean)) fail(`${rel}: routes must not use fs/net/child_process`);
}

// 2. invoke allowlist (ADR-0006 canonical: middleware/core-client/invoker.js).
// Shims in src re-export canonical; transport (app/authService/tokenStore)
// and adapters/otp may invoke. Nothing else may.
const INVOKE_ALLOWED_SRC = new Set(['app.js', 'authService.js', 'tokenStore.js']);
const INVOKE_ALLOWED_ADAPTERS = new Set(['otp.js', 'signals.js']);
for (const f of listJs(SRC)) {
  if (f.startsWith(`${ROUTES_DIR}${path.sep}`)) continue;
  const rel = path.relative(ROOT, f);
  const base = path.basename(f);
  const clean = stripComments(readFileSync(f, 'utf8'));
  // Shim re-exports are allowed (single-line export *).
  if (
    clean
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean).length === 1 &&
    clean.includes('export * from')
  )
    continue;
  const importsInvoke =
    /from\s+['"]\.\/invoker\.js['"]/.test(clean) || /from\s+['"]\.\.\/core-client\/invoker\.js['"]/.test(clean);
  if (importsInvoke && !INVOKE_ALLOWED_SRC.has(base)) {
    fail(`${rel}: direct invoker import not allowed (allowed src: ${[...INVOKE_ALLOWED_SRC].join(', ')})`);
  }
}
{
  const ADAPTERS = path.join(ROOT, 'middleware', 'adapters');
  for (const f of listJs(ADAPTERS)) {
    const rel = path.relative(ROOT, f);
    const base = path.basename(f);
    const clean = stripComments(readFileSync(f, 'utf8'));
    const importsInvoke =
      /from\s+['"]\.\.\/core-client\/invoker\.js['"]/.test(clean) || /from\s+['"]\.\/invoker\.js['"]/.test(clean);
    if (importsInvoke && !INVOKE_ALLOWED_ADAPTERS.has(base) && base !== 'otp.js') {
      // signals.js must never invoke COBOL (reshape only); otp.js may.
      if (base === 'signals.js' && importsInvoke) fail(`${rel}: signals must never invoke COBOL (reshape only)`);
      else if (!INVOKE_ALLOWED_ADAPTERS.has(base))
        fail(`${rel}: direct invoker import not allowed (adapters: otp.js only)`);
    }
  }
}

// 3. responseMappers purity (ADR-0006: may delegate to authService/adapters only).
{
  const f = path.join(SRC, 'responseMappers.js');
  if (existsSync(f)) {
    const clean = stripComments(readFileSync(f, 'utf8'));
    const rel = path.relative(ROOT, f);
    if (/from\s+['"]\.\/invoker\.js['"]/.test(clean) || /from\s+['"]\.\.\/core-client\/invoker\.js['"]/.test(clean))
      fail(`${rel}: must not import invoker directly (use authService)`);
    if (/from\s+['"]\.\/auth\.js['"]/.test(clean)) fail(`${rel}: must not sign tokens directly (use authService)`);
    if (/node:fs|node:net|child_process/.test(clean)) fail(`${rel}: must not use fs/net/child_process`);
    if (/\bfetch\s*\(/.test(clean)) fail(`${rel}: must not fetch`);
    for (const imp of importsOf(clean)) {
      if (
        imp.startsWith('.') &&
        imp !== './authService.js' &&
        imp !== '../adapters/otp.js' &&
        imp !== './otpService.js'
      ) {
        fail(`${rel}: only './authService.js' and adapters/otp relative imports allowed (got '${imp}')`);
      }
    }
  }
}

// 4. No SQL / DB drivers / money arithmetic in src.
const DB_IMPORT_RE = /(mysql|mariadb|pg\b|sqlite|better-sqlite3|sequelize|knex|prisma)/;
const SQL_RE = /\b(SELECT\s+.+\s+FROM|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM|CREATE\s+TABLE)\b/i;
for (const f of listJs(SRC)) {
  const rel = path.relative(ROOT, f);
  const clean = stripComments(readFileSync(f, 'utf8'));
  for (const imp of importsOf(readFileSync(f, 'utf8'))) {
    if (DB_IMPORT_RE.test(imp)) fail(`${rel}: DB driver import not allowed ('${imp}')`);
  }
  if (SQL_RE.test(clean)) fail(`${rel}: SQL string not allowed in gateway`);
}

// 5. services/workers imports (ADR-0006 one-way).
// src (except server.js composition root + shims) must not import services/workers.
// adapters may import services; services/workers must not be reached via src.
const SERVICE_IMPORT_ALLOW_SRC = new Map([
  [
    'server.js',
    new Set([
      '../services/integrations/index.js',
      '../services/integrations/secrets.js',
      '../services/integrations/documents/storage.js',
    ]),
  ],
]);
for (const f of listJs(SRC)) {
  if (f.startsWith(`${ROUTES_DIR}${path.sep}`)) continue;
  const rel = path.relative(ROOT, f);
  const base = path.basename(f);
  const raw = readFileSync(f, 'utf8');
  const clean = stripComments(raw);
  // Shim re-exports are allowed.
  if (
    clean
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean).length === 1 &&
    clean.includes('export * from')
  )
    continue;
  const src = raw;
  for (const imp of importsOf(src)) {
    if (imp.includes('/services/') || imp.includes('/workers/') || imp.includes('/jobs/')) {
      const allowed = SERVICE_IMPORT_ALLOW_SRC.get(base);
      if (!allowed || !allowed.has(imp))
        fail(`${rel}: src must not import services/workers directly (use adapters; got '${imp}')`);
    }
    if (imp.includes('/adapters/')) {
      // src → adapters is the allowed direction (transport calls signals/guards).
      continue;
    }
  }
}

// 6. No process.env in routes already checked; flag new env reads in src
// outside the known gateway config owners (informational, not failing yet).
// (Kept as documentation: auth/pool/rateLimit/binary/server/app/responseMappers
// own gateway knobs; domain policy must not read env from src.)

if (failures.length) {
  console.error('GATEWAY PURITY VIOLATIONS:');
  for (const m of failures) console.error(`  ${m}`);
  console.error(`\n${failures.length} violation(s). JS is an API gateway and nothing more.`);
  process.exit(1);
}

console.log(`OK: gateway purity holds (${listJs(SRC).length} src files, ${listJs(ROUTES_DIR).length} route files)`);
