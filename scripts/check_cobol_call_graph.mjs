// COBOL call-graph gate (ADR-0006): cross-module CALLs are explicit.
//   - CALL targets must be known: C bridge/runtime symbols or registered
//     COBOL modules. An unknown target is a typo or an unreviewed seam.
//   - COBOL→COBOL edges must be listed in manifest/cobol_calls.json.
//     A new edge (e.g. a job orchestrator calling another domain) changes
//     transaction and failure semantics, so it needs review, not silence.
//   - The graph must be acyclic: a CALL cycle between modules risks
//     unbounded recursion inside one request.
// C-bridge/runtime allowlist: SQL_*, SET_QUERY, GET_RESULT (the C bridge)
// plus the crypto/settings helpers from cobol/c_lib.
// Usage: node scripts/check_cobol_call_graph.mjs [--write] [root]
import { readdirSync, readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const WRITE = args.includes('--write');
const ROOT = path.resolve(args.find((a) => !a.startsWith('--')) || '.');
const SRC = path.join(ROOT, 'cobol', 'src');
const COPY_DIR = path.join(ROOT, 'cobol', 'copy');
const OUT = path.join(ROOT, 'manifest', 'cobol_calls.json');

// Paragraph extractions move CALLs into COPYbooks that compile into the
// including module. Expand one level (copybooks do not nest here) so the
// edge still belongs to the module that actually makes the call.
function withCopies(src) {
  let out = src;
  for (const m of src.matchAll(/COPY "([a-z0-9_]+\.cpy)"/g)) {
    try {
      out += '\n' + readFileSync(path.join(COPY_DIR, m[1]), 'utf8');
    } catch {
      // Missing include is another gate's failure; keep this one focused.
    }
  }
  return out;
}

// C bridge + cobol/c_lib runtime symbols (never COBOL modules).
const RUNTIME_RE = /^(SQL_|SET_QUERY|GET_RESULT)/;
const RUNTIME_SYMBOLS = new Set([
  'generate_random_code',
  'generate_mfa_secret',
  'env_or',
  'env_or_raw',
  'verify_password',
  'hash_password_v2',
  'password_needs_rehash',
  'totp_verify',
  'sha256_hex_lower',
]);

const modules = new Set(
  readdirSync(SRC)
    .filter((x) => x.endsWith('.cob'))
    .map((x) => x.replace(/\.cob$/, '')),
);

const edges = new Map(); // "from -> to" -> {from, to, callsites}
const failures = [];
const fail = (m) => failures.push(m);

for (const f of [...modules].sort()) {
  const src = withCopies(readFileSync(path.join(SRC, `${f}.cob`), 'utf8'));
  for (const m of src.matchAll(/CALL\s+"([A-Za-z0-9_]+)"/g)) {
    const target = m[1];
    if (RUNTIME_RE.test(target) || RUNTIME_SYMBOLS.has(target)) continue;
    if (!modules.has(target)) {
      fail(`${f}.cob: CALL to unknown target "${target}"`);
      continue;
    }
    if (target === f) {
      fail(`${f}.cob: self-CALL "${target}" (recursion inside one request)`);
      continue;
    }
    const key = `${f} -> ${target}`;
    if (!edges.has(key)) edges.set(key, { from: f, to: target, callsites: 0 });
    edges.get(key).callsites += 1;
  }
}

// Cycle detection over the module graph.
{
  const adj = new Map();
  for (const { from, to } of edges.values()) {
    if (!adj.has(from)) adj.set(from, []);
    adj.get(from).push(to);
  }
  const state = new Map(); // 1 = on stack, 2 = done
  const stack = [];
  const visit = (n) => {
    state.set(n, 1);
    stack.push(n);
    for (const m of adj.get(n) || []) {
      if (state.get(m) === 1) {
        fail(`CALL cycle: ${[...stack, m].join(' -> ')}`);
      } else if (!state.get(m)) {
        visit(m);
      }
    }
    stack.pop();
    state.set(n, 2);
  };
  for (const n of adj.keys()) if (!state.get(n)) visit(n);
}

const doc = {
  generatedAt: new Date().toISOString(),
  generator: 'scripts/check_cobol_call_graph.mjs (do not hand-edit)',
  count: edges.size,
  edges: [...edges.values()].sort((a, b) => (a.from < b.from ? -1 : a.from > b.from ? 1 : a.to < b.to ? -1 : 1)),
};

if (WRITE) {
  mkdirSync(path.dirname(OUT), { recursive: true });
  writeFileSync(OUT, `${JSON.stringify(doc, null, 2)}\n`);
  console.log(`wrote ${path.relative(ROOT, OUT)}: ${edges.size} edges`);
} else {
  if (!existsSync(OUT)) {
    console.error(`FAIL: missing ${path.relative(ROOT, OUT)}; run with --write`);
    process.exit(1);
  }
  const current = JSON.parse(readFileSync(OUT, 'utf8'));
  const norm = (d) => JSON.stringify(d.edges);
  if (norm(current) !== norm(doc)) {
    const cur = new Set((current.edges || []).map((e) => `${e.from} -> ${e.to}`));
    const live = new Set(doc.edges.map((e) => `${e.from} -> ${e.to}`));
    for (const e of [...live].filter((x) => !cur.has(x))) fail(`new unreviewed CALL edge: ${e}`);
    for (const e of [...cur].filter((x) => !live.has(x)))
      fail(`stale CALL edge (call removed, registry left behind): ${e}`);
  }
}

if (failures.length) {
  console.error('COBOL CALL-GRAPH VIOLATIONS (ADR-0006):');
  for (const m of failures) console.error(`  ${m}`);
  process.exit(1);
}

if (!WRITE) console.log(`OK: call graph holds (${edges.size} reviewed edges, acyclic)`);
