// Contract gate (ADR-0006 follow-up): the registry must match reality.
//   1. contracts/actions.yaml in sync (routes + manifest) — same stripped
//      comparison as build_contract.mjs check mode.
//   2. Every contract entry resolves to manifest dispatch (module + prefix).
//   3. Every contract (method, path) exists in docs/openapi.yaml.
// Usage: node scripts/check_contract.mjs [root]
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const ROOT = path.resolve(process.argv[2] || '.');
const CONTRACT = path.join(ROOT, 'contracts', 'actions.yaml');
const MANIFEST = path.join(ROOT, 'manifest', 'actions.json');
const OPENAPI = path.join(ROOT, 'docs', 'openapi.yaml');

const failures = [];
const fail = (m) => failures.push(m);

// 1. Drift: delegate to the builder's check mode (single implementation).
{
  const r = spawnSync(process.execPath, [path.join(ROOT, 'scripts', 'build_contract.mjs'), ROOT], {
    encoding: 'utf8',
  });
  if (r.status !== 0) {
    fail((r.stderr || r.stdout || 'build_contract check failed').trim().split('\n')[0]);
  }
}

if (!existsSync(CONTRACT)) {
  console.error('FAIL: missing contracts/actions.yaml; run scripts/build_contract.mjs --write');
  process.exit(1);
}
const contractSrc = readFileSync(CONTRACT, 'utf8');
const manifest = JSON.parse(readFileSync(MANIFEST, 'utf8'));
const byAction = new Map();
for (const a of manifest.actions || []) {
  if (!byAction.has(a.action)) byAction.set(a.action, []);
  byAction.get(a.action).push(a);
}
const openapi = readFileSync(OPENAPI, 'utf8');

// Minimal extraction of contract entries (same shape the builder emits).
// Parses `  - action: X` blocks with their method/path/module/prefix lines.
{
  const blocks = contractSrc.split(/^\s+- action: /m).slice(1);
  const seen = new Set();
  for (const b of blocks) {
    const action = b.split('\n', 1)[0].trim();
    const method = (b.match(/^\s+method: (\w+)/m) || [])[1] || null;
    // Path may be plain or JSON-quoted (colons force quoting in the emitter).
    const rawPath = (b.match(/^\s+path: (.+)$/m) || [])[1] || null;
    let routePath = rawPath;
    if (rawPath && rawPath.startsWith('"')) {
      try {
        routePath = JSON.parse(rawPath);
      } catch {
        routePath = rawPath;
      }
    }
    const module = (b.match(/^\s+module: (\S+)/m) || [])[1] || null;
    const prefix = (b.match(/^\s+prefix: (\S+)/m) || [])[1] || null;
    const key = `${method} ${routePath} ${action}`;
    if (seen.has(key)) fail(`duplicate contract entry: ${key}`);
    seen.add(key);

    // 2. Dispatch: action must resolve to a manifest module + prefix.
    const hits = byAction.get(action) || [];
    if (!hits.length) {
      fail(`contract action without manifest dispatch: ${action}`);
    } else if (!hits.some((h) => h.module === module && h.prefix === prefix)) {
      fail(`contract dispatch mismatch: ${action} (contract ${module}/${prefix})`);
    }
    for (const h of hits) {
      if (!h.module || !h.prefix) fail(`manifest dispatch incomplete: ${action}`);
    }

    // 3. OpenAPI: the route must be documented (path block + method key).
    if (!method || !routePath) {
      fail(`contract entry missing method/path: ${action}`);
      continue;
    }
    const lines = openapi.split('\n');
    const indent2 = '  ';
    const indent4 = '    ';
    const hit = lines.findIndex((ln) => ln === `${indent2}${routePath}:` || ln === `${indent2}"${routePath}":`);
    if (hit === -1) {
      fail(`contract route missing in openapi: ${method.toUpperCase()} ${routePath} (${action})`);
      continue;
    }
    let end = lines.length;
    for (let i = hit + 1; i < lines.length; i += 1) {
      if (lines[i].startsWith(indent2) && !lines[i].startsWith(indent4)) {
        end = i;
        break;
      }
    }
    const block = lines.slice(hit, end);
    if (!block.some((ln) => ln === `${indent4}${method}:`)) {
      fail(`contract method missing in openapi: ${method.toUpperCase()} ${routePath} (${action})`);
    }
  }
}

if (failures.length) {
  console.error('CONTRACT CHECK FAILED:');
  for (const m of failures.slice(0, 20)) console.error(`  - ${m}`);
  if (failures.length > 20) console.error(`  ... and ${failures.length - 20} more`);
  process.exit(1);
}

// Count entries for the OK line (same split as above).
const count = contractSrc.split(/^\s+- action: /m).length - 1;
console.log(`OK: contract holds (${count} route entries, dispatch + openapi linked)`);
