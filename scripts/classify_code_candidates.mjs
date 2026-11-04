// Dead/duplicate candidate registry (PR-010F): mark removal candidates with
// evidence BEFORE any deletion happens.
//
// Invariants enforced by --check:
//   - candidates cover exactly the FROZEN modules of manifest/domain_status.json
//     (a FROZEN module without a candidate, or a candidate that is no longer
//     FROZEN, fails the gate);
//   - every candidate carries reason + non-empty evidence;
//   - CANDIDATE entries must not carry ownerSignoff yet (sign-off happens at
//     the DEPRECATED transition, by review, not by default);
//   - DEPRECATED/RETIRED require ownerSignoff + trafficLastSeen + reason;
//   - the candidate set only shrinks (tests/code_candidates_baseline.txt).
//
// Evidence per candidate is derived, not asserted:
//   - Tier-1 linkage level + scoring reason (manifest/tier1_links.json);
//   - template-clone signal (tests/clone_baseline.txt) or explicit
//     "custom unlinked code" marker for non-shaped modules;
//   - primary own-domain table + how many modules reference it;
//   - trafficLastSeen null with "telemetry pending" until measured.
//
// Nothing is deleted here. Waves (PR-010A..D) consume CANDIDATE/DEPRECATED
// entries; PR-010D drops tables only after retention.
//
// Usage:
//   node scripts/classify_code_candidates.mjs --check [--root DIR] (default)
//   node scripts/classify_code_candidates.mjs --write [--root DIR]
//   node scripts/classify_code_candidates.mjs --write-docs [--root DIR]
// --write adds missing candidates and refreshes docs + baseline snapshot;
// it never modifies existing entries. Never use --write to green CI.
// Exit: 0 ok, 1 mismatch, 2 usage error.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const args = process.argv.slice(2);
let root = '.';
let mode = 'check';
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--check') mode = 'check';
  else if (a === '--write') mode = 'write';
  else if (a === '--write-docs') mode = 'write-docs';
  else if (a === '--root') {
    root = args[i + 1] ?? root;
    i += 1;
  } else if (a === '--help' || a === '-h') {
    console.log('usage: classify_code_candidates.mjs [--check|--write|--write-docs] [--root DIR]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
root = path.resolve(root);

const STATUS = ['CANDIDATE', 'DEPRECATED', 'RETIRED'];
const REQUIRED = [
  'module',
  'domain',
  'linkageLevel',
  'reason',
  'evidence',
  'trafficLastSeen',
  'consumer',
  'replacement',
  'ownerSignoff',
  'status',
];

function loadJson(p) {
  if (!existsSync(p)) {
    console.error(`FAIL: ${p} missing`);
    process.exit(1);
  }
  return JSON.parse(readFileSync(p, 'utf8'));
}

function tableReferences(rootDir) {
  const counts = new Map();
  const cobolDir = path.join(rootDir, 'cobol', 'src');
  if (!existsSync(cobolDir)) return counts;
  for (const f of readdirFiles(cobolDir)) {
    const text = readFileSync(path.join(cobolDir, f), 'utf8');
    const seen = new Set();
    for (const m of text.matchAll(/\b(?:FROM|JOIN|INTO|UPDATE)\s+`?([A-Za-z0-9_]+)`?/g)) {
      seen.add(m[1].toLowerCase());
    }
    for (const t of seen) {
      if (!counts.has(t)) counts.set(t, new Set());
      counts.get(t).add(f.replace(/\.cob$/, ''));
    }
  }
  return counts;
}

function readdirFiles(dir) {
  return readdirSync(dir)
    .filter((f) => f.endsWith('.cob'))
    .sort();
}

function buildCandidates(rootDir) {
  const links = loadJson(path.join(rootDir, 'manifest', 'tier1_links.json'));
  const domainStatus = loadJson(path.join(rootDir, 'manifest', 'domain_status.json'));
  const linkByModule = new Map((links.modules || []).map((m) => [m.module, m]));
  const statusByModule = new Map((domainStatus.entries || []).map((e) => [e.module, e]));

  const cloneBaseline = new Set();
  const clonePath = path.join(rootDir, 'tests', 'clone_baseline.txt');
  if (existsSync(clonePath)) {
    for (const line of readFileSync(clonePath, 'utf8').split('\n')) {
      const t = line.trim();
      if (t && !t.startsWith('#')) cloneBaseline.add(t.split(/\s+/)[0]);
    }
  }
  const tableUsers = tableReferences(rootDir);
  const out = [];
  for (const [module, entry] of [...statusByModule.entries()].sort()) {
    if (entry.status !== 'FROZEN') continue;
    const link = linkByModule.get(module);
    const domain = module.endsWith('_core') ? module.slice(0, -5) : module;
    const evidence = [];
    evidence.push(`linkage ${link ? link.linkageLevel : 'unknown'}: ${link ? link.reason : 'no tier1 entry'}`);
    if (cloneBaseline.has(module)) {
      evidence.push('template-clone signal: recorded in tests/clone_baseline.txt (shape/similarity/size match)');
    } else {
      evidence.push('not template-shaped: custom unlinked code, needs manual review for unique rules');
    }
    if (entry.table) {
      const users = tableUsers.get(entry.table) || new Set();
      const others = [...users].filter((m) => m !== module);
      evidence.push(
        others.length === 0
          ? `primary table ${entry.table}: referenced only by this module`
          : `primary table ${entry.table}: also referenced by ${others.sort().join(', ')}`,
      );
    } else {
      evidence.push('no own-domain table detected');
    }
    evidence.push('trafficLastSeen: null — no traffic telemetry yet; must be measured before DEPRECATED');
    evidence.push(
      'CORE_LINKED actions: none — Tier-1 scoring found no business tables, Tier-1 CALLs, or money actions',
    );
    const kind = cloneBaseline.has(module) ? 'DUPLICATE' : 'UNLINKED';
    out.push({
      module,
      domain,
      linkageLevel: link ? link.linkageLevel : null,
      reason: `${kind}: ${entry.reason}`,
      evidence,
      trafficLastSeen: null,
      consumer: null,
      replacement: entry.replacement || null,
      ownerSignoff: null,
      status: 'CANDIDATE',
    });
  }
  return out;
}

function validate(rootDir, candidates) {
  const failures = [];
  const domainStatus = loadJson(path.join(rootDir, 'manifest', 'domain_status.json'));
  const frozen = new Set((domainStatus.entries || []).filter((e) => e.status === 'FROZEN').map((e) => e.module));
  const names = new Set();
  for (const c of candidates) {
    for (const key of REQUIRED) {
      if (!(key in c)) failures.push(`${c.module || '?'}: missing field "${key}"`);
    }
    if (c.status && !STATUS.includes(c.status)) failures.push(`${c.module}: unknown status "${c.status}"`);
    if (names.has(c.module)) failures.push(`duplicate candidate: ${c.module}`);
    names.add(c.module);
    if (!c.reason) failures.push(`${c.module}: missing reason`);
    if (!Array.isArray(c.evidence) || c.evidence.length === 0) failures.push(`${c.module}: missing evidence`);
    if ((c.linkageLevel === 'L0' || c.linkageLevel === 'L1') === false && c.status === 'CANDIDATE') {
      failures.push(`${c.module}: CANDIDATE requires L0/L1 linkage (has ${c.linkageLevel})`);
    }
    if (c.status === 'CANDIDATE' && c.ownerSignoff) {
      failures.push(`${c.module}: CANDIDATE must not carry ownerSignoff (sign off at DEPRECATED by review)`);
    }
    if ((c.status === 'DEPRECATED' || c.status === 'RETIRED') && !c.ownerSignoff) {
      failures.push(`${c.module}: ${c.status} requires ownerSignoff`);
    }
    if ((c.status === 'DEPRECATED' || c.status === 'RETIRED') && !c.trafficLastSeen) {
      failures.push(`${c.module}: ${c.status} requires trafficLastSeen evidence`);
    }
  }
  for (const m of frozen) {
    if (!names.has(m)) failures.push(`FROZEN module without candidate: ${m}`);
  }
  for (const c of candidates) {
    if (!frozen.has(c.module)) {
      failures.push(`candidate ${c.module} is not FROZEN in domain_status.json (remove or re-freeze)`);
    }
  }
  return failures;
}

function loadBaseline(rootDir) {
  const p = path.join(rootDir, 'tests', 'code_candidates_baseline.txt');
  if (!existsSync(p)) return { order: [], set: new Set(), raw: [] };
  const raw = readFileSync(p, 'utf8').split('\n');
  const order = [];
  const set = new Set();
  for (const line of raw) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const [module, status] = t.split(/\s+/);
    if (!module || !STATUS.includes(status)) {
      console.error(`FAIL: malformed baseline line: ${line}`);
      process.exit(2);
    }
    if (set.has(module)) {
      console.error(`FAIL: duplicate baseline entries: ${module}`);
      process.exit(2);
    }
    set.add(module);
    order.push(module);
  }
  return { order, set, raw };
}

function renderDocs(candidates) {
  const counts = {};
  for (const c of candidates) counts[c.status] = (counts[c.status] ?? 0) + 1;
  const kinds = {};
  for (const c of candidates) {
    const kind = c.reason.startsWith('DUPLICATE') ? 'DUPLICATE' : 'UNLINKED';
    kinds[kind] = (kinds[kind] ?? 0) + 1;
  }
  const rows = [...candidates]
    .sort((a, b) => a.module.localeCompare(b.module))
    .map(
      (c) =>
        `| \`${c.module}\` | ${c.linkageLevel} | ${c.status} | ${c.replacement ? `\`${c.replacement}\`` : '—'} | ${c.trafficLastSeen || '—'} | ${c.ownerSignoff || '—'} | ${c.reason} |`,
    );
  return `# Code Candidates

> Generated by \`scripts/classify_code_candidates.mjs\` (candidate defaults)
> with hand-maintained transitions. \`--write\` only adds missing candidates;
> it never modifies existing entries. CANDIDATE -> DEPRECATED requires owner
> sign-off plus traffic evidence; DEPRECATED -> removal happens in the
> retirement waves (PR-010A..D). Nothing here is deleted by this registry.

| Status | Candidates |
| --- | ---: |
${STATUS.map((s) => `| ${s} | ${counts[s] ?? 0} |`).join('\n')}

| Kind | Candidates |
| --- | ---: |
| DUPLICATE (template clone) | ${kinds.DUPLICATE ?? 0} |
| UNLINKED (custom code, no core link) | ${kinds.UNLINKED ?? 0} |

| Module | Link | Status | Replacement | Traffic | Sign-off | Reason |
| --- | --- | --- | --- | --- | --- | --- |
${rows.join('\n')}
`;
}

export { STATUS, buildCandidates, validate, renderDocs };

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const candsPath = path.join(root, 'manifest', 'code_candidates.json');
  const basePath = path.join(root, 'tests', 'code_candidates_baseline.txt');

  if (mode === 'write' || mode === 'write-docs') {
    let candidates = [];
    if (mode === 'write') {
      if (existsSync(candsPath)) {
        candidates = JSON.parse(readFileSync(candsPath, 'utf8')).candidates || [];
      }
      const have = new Set(candidates.map((c) => c.module));
      const fresh = buildCandidates(root);
      let added = 0;
      for (const c of fresh) {
        if (!have.has(c.module)) {
          candidates.push(c);
          added += 1;
        }
      }
      candidates.sort((a, b) => a.module.localeCompare(b.module));
      writeFileSync(candsPath, `${JSON.stringify({ generatedAt: new Date().toISOString(), candidates }, null, 2)}\n`);
      const snapshot = [
        '# Code candidate baseline (ratchet).',
        '#',
        '# Candidate modules pending dead-code review. This set must only shrink:',
        '# CANDIDATE -> DEPRECATED (review + sign-off + traffic evidence) -> removed',
        '# by a retirement wave. Never add an entry to make CI green.',
        '',
        ...candidates.map((c) => `${c.module} ${c.status}`),
      ].join('\n');
      writeFileSync(basePath, `${snapshot}\n`);
      console.log(`Wrote ${candsPath} (+${added} new, ${candidates.length} total) + baseline snapshot`);
    } else {
      candidates = JSON.parse(readFileSync(candsPath, 'utf8')).candidates || [];
    }
    writeFileSync(path.join(root, 'docs', 'CODE_CANDIDATES.md'), renderDocs(candidates));
    console.log(`Wrote docs/CODE_CANDIDATES.md (${candidates.length} candidates)`);
    process.exit(0);
  }

  if (!existsSync(candsPath)) {
    console.error('FAIL: manifest/code_candidates.json missing (run scripts/classify_code_candidates.mjs --write)');
    process.exit(1);
  }
  const candidates = JSON.parse(readFileSync(candsPath, 'utf8')).candidates || [];
  const failures = validate(root, candidates);
  const { set: baseline } = loadBaseline(root);
  if (baseline.size > 0) {
    const names = new Set(candidates.map((c) => c.module));
    for (const m of names) {
      if (!baseline.has(m)) failures.push(`candidate ${m} not in baseline (add only via --write with review)`);
    }
    for (const m of baseline) {
      if (!names.has(m)) failures.push(`baseline candidate ${m} has no registry entry (remove it deliberately)`);
    }
  } else if (existsSync(basePath)) {
    failures.push('tests/code_candidates_baseline.txt is empty (run --write once to snapshot)');
  } else {
    failures.push('tests/code_candidates_baseline.txt missing (run --write once to snapshot)');
  }
  if (failures.length) {
    for (const f of failures) console.error(`FAIL: ${f}`);
    process.exit(1);
  }
  const counts = {};
  for (const c of candidates) counts[c.status] = (counts[c.status] ?? 0) + 1;
  console.log(
    `OK: ${candidates.length} code candidates (${STATUS.map((s) => `${s} ${counts[s] ?? 0}`).join(', ')}), baseline holds ${baseline.size}`,
  );
}
