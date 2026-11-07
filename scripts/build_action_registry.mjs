// Action registry builder (PR-050): single metadata for every gateway
// action — route shape + dispatch program + linkage + domain disposition.
// Generated from routes/*.js + main_logic.cob + manifests; never hand-edit.
// Usage: node scripts/build_action_registry.mjs [--write]
import { readFileSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { ALL_ROUTES } from '../middleware/src/routes/index.js';
import { parseDispatchTable, loadDispatchSource } from './lib/dispatch_table.mjs';
import { ownerFor } from './lib/route_owners.mjs';

const ROOT = new URL('..', import.meta.url).pathname.replace(/\/$/, '');
const WRITE = process.argv.includes('--write');
const OUT = `${ROOT}/manifest/actions.json`;

function headCommit() {
  try {
    return execSync('git rev-parse --short HEAD', { cwd: ROOT }).toString().trim();
  } catch {
    return 'unknown';
  }
}

// Longest-prefix-first, mirroring DISPATCH-ACTION.
function resolveAction(action, entries) {
  let best = null;
  for (const e of entries) {
    if (action.startsWith(e.prefix) && (!best || e.prefix.length > best.prefix.length)) best = e;
  }
  return best;
}

const mainLogic = loadDispatchSource(ROOT);
const { entries: dispatch, problems } = parseDispatchTable(mainLogic);
if (problems.length) {
  console.error(`dispatch problems:\n${problems.join('\n')}`);
  process.exit(1);
}
const tier1 = JSON.parse(readFileSync(`${ROOT}/manifest/tier1_links.json`, 'utf8'));
const domains = JSON.parse(readFileSync(`${ROOT}/manifest/domain_status.json`, 'utf8'));
const byModule = new Map();
for (const e of tier1.modules || []) byModule.set(e.module, e);
for (const e of domains.entries || domains) {
  if (!byModule.has(e.module)) byModule.set(e.module, {});
  Object.assign(byModule.get(e.module), {
    domain: e.domain,
    status: e.status,
    linkageLevel: e.linkageLevel,
    routeFile: e.routeFile,
  });
}

const seen = new Map();
const actions = [];
for (const r of ALL_ROUTES) {
  if (seen.has(r.action)) {
    seen.get(r.action).duplicatePaths = true;
    continue;
  }
  const hit = resolveAction(r.action, dispatch);
  const info = (hit && byModule.get(hit.program)) || {};
  const owned = ownerFor(r.path);
  const entry = {
    action: r.action,
    module: hit ? hit.program : null,
    prefix: hit ? hit.prefix : null,
    method: r.method,
    path: r.path,
    fields: (r.fields || []).map((f) => f.name ?? ''),
    required: (r.fields || []).map((f) => Boolean(f.required)),
    public: Boolean(r.public),
    stepUp: Boolean(r.stepUp || r.stepUpPolicy),
    tokenIdentity: r.tokenIdentity || null,
    owner: owned ? owned.owner : null,
    authPolicy: owned ? owned.policy : null,
    linkageLevel: info.linkageLevel || null,
    t1Actions: info.t1Actions || [],
    t1Calls: info.t1Calls || [],
    tested: Boolean(info.hasTests),
    domain: info.domain || null,
    status: info.status || null,
  };
  seen.set(r.action, entry);
  actions.push(entry);
}
actions.sort((a, b) => (a.action < b.action ? -1 : 1));

const unmapped = actions.filter((a) => !a.module);
const registry = {
  generatedAt: new Date().toISOString(),
  commit: headCommit(),
  generator: 'scripts/build_action_registry.mjs (do not hand-edit)',
  count: actions.length,
  actions,
  dispatch: [...dispatch]
    .sort((a, b) => a.slot - b.slot)
    .map((e) => ({ slot: e.slot, prefix: e.prefix, prefixLen: e.prefixLen, program: e.program })),
};

if (!WRITE) {
  let current = null;
  try {
    current = JSON.parse(readFileSync(OUT, 'utf8'));
  } catch {
    console.error('registry missing: run scripts/build_action_registry.mjs --write');
    process.exit(1);
  }
  const { generatedAt: _ga, commit: _cb, ...restCurrent } = current;
  const { generatedAt: _gc, commit: _cd, ...restFresh } = registry;
  void _ga;
  void _cb;
  void _gc;
  void _cd;
  if (JSON.stringify(restCurrent) !== JSON.stringify(restFresh)) {
    console.error('action registry drifted: run scripts/build_action_registry.mjs --write and review the diff');
    process.exit(1);
  }
  console.log(`OK: action registry in sync (${actions.length} actions)`);
} else {
  writeFileSync(OUT, `${JSON.stringify(registry, null, 2)}\n`);
  console.log(`wrote ${OUT}: ${actions.length} actions`);
}
if (unmapped.length) {
  console.error(
    `WARN: ${unmapped.length} action(s) without dispatch program: ${unmapped.map((a) => a.action).join(', ')}`,
  );
}
