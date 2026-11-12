// Integration completion audit (PR-010E): every L2/L3 module kept in the tree
// must be CONNECTED to the Tier-1 core, not merely present.
//
// For each L2/L3 module (manifest/tier1_links.json) the audit checks:
//   actions - every ACTION-*/LOGIC paragraph (except MAIN-LOGIC): CORE_LINKED
//             when its body touches a business table, CALLs a Tier-1 module,
//             uses a money action literal, or mutates the identity table
//             (users reads/writes inside an action body; the ALLOW-ADMIN role
//             lookup itself is still NOT linkage). Otherwise a write paragraph
//             becomes a backlog item; pure-read paragraphs are exempt and only
//             listed in docs (a paged LIST needs no core link to be correct).
//   tables  - every own-domain table must carry a core business key
//             (account/customer/loan/card/journal/deposit/collection/merchant
//             id) or a FOREIGN KEY into a Tier-1 table, found in CREATE TABLE
//             plus later ALTER TABLE ... ADD COLUMN. Otherwise backlog.
//   routes  - the module must have a DB/table/integration test proving the
//             link (auth/shape depth stays with check_route_auth and the
//             field-order gate; this gate does not duplicate them).
//   audit   - one manual item per module: verify audit rows store a core
//             reference. Automation cannot prove old/new-value semantics.
//
// Module status is DERIVED (not stored): CONNECTED = no OPEN/IN_PROGRESS
// items; PARTIAL otherwise. No new features here: items are closed by wiring
// the missing link or by WAIVED with an accepted-risk reason + owner.
//
// Usage:
//   node scripts/check_integration_completion.mjs --check [--root DIR] (default)
//   node scripts/check_integration_completion.mjs --write [--root DIR]
//   node scripts/check_integration_completion.mjs --write-docs [--root DIR]
// --write adds missing computed-OPEN items and refreshes docs; it never
// modifies existing entries. Never use --write to green CI.
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
    console.log('usage: check_integration_completion.mjs [--check|--write|--write-docs] [--root DIR]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
root = path.resolve(root);

const STATUS = ['OPEN', 'IN_PROGRESS', 'DONE', 'WAIVED'];
const KINDS = ['action', 'table', 'route', 'audit'];
const REQUIRED = ['id', 'module', 'kind', 'subject', 'status', 'reason', 'evidence', 'owner'];
const NOISE_TABLES = new Set(['ls', 'ws', 'when', 'set', 'values', 'into']);
const CORE_KEYS = new Set([
  'account_id',
  'customer_id',
  'loan_id',
  'loan_application_id',
  'card_id',
  'card_account_id',
  'journal_id',
  'gl_journal_id',
  'deposit_id',
  'deposit_account_id',
  'collection_id',
  'merchant_id',
]);

function loadJson(p) {
  if (!existsSync(p)) {
    console.error(`FAIL: ${p} missing`);
    process.exit(1);
  }
  return JSON.parse(readFileSync(p, 'utf8'));
}

function isRefish(t) {
  return t === 'users' || t === 'currencies' || t.startsWith('ref_');
}

function splitParagraphs(source) {
  const lines = source.split('\n');
  const paras = new Map();
  let cur = null;
  for (const line of lines) {
    const m = line.match(/^ {4,8}([A-Z0-9][A-Z0-9-]*)\.\s*$/);
    if (m && !m[1].startsWith('END-') && !['ELSE', 'CONTINUE', 'GOBACK', 'EXIT'].includes(m[1])) {
      cur = m[1];
      paras.set(cur, []);
    } else if (cur !== null) {
      paras.get(cur).push(line);
    }
  }
  return paras;
}

function tableRefs(text) {
  const out = new Set();
  for (const m of text.matchAll(/\b(?:FROM|JOIN|INTO|UPDATE)\s+`?([A-Za-z0-9_]+)`?/g)) {
    // COBOL loop bounds (PERFORM VARYING i FROM 256 ...) are not tables.
    if (/^\d+$/.test(m[1])) continue;
    out.add(m[1].toLowerCase());
  }
  return out;
}

function writeRefs(text) {
  const out = new Set();
  for (const m of text.matchAll(/\b(?:INTO|UPDATE)\s+`?([A-Za-z0-9_]+)`?/g)) {
    const t = m[1].toLowerCase();
    if (/^\d+$/.test(t)) continue;
    if (!NOISE_TABLES.has(t)) out.add(t);
  }
  return out;
}

// Column + FK index over schema.sql and every migration (CREATE plus later
// ALTER TABLE ... ADD COLUMN; first CREATE wins for existence).
function buildSchemaIndex(rootDir) {
  const columns = new Map();
  const fks = new Map();
  const files = [];
  const migDir = path.join(rootDir, 'database', 'migrations');
  const archDir = path.join(migDir, 'archive');
  for (const dir of [migDir, archDir]) {
    if (!existsSync(dir)) continue;
    for (const f of readdirSync(dir)
      .filter((x) => x.endsWith('.sql'))
      .sort()) {
      files.push(path.join(dir, f));
    }
  }
  const schema = path.join(rootDir, 'database', 'schema.sql');
  if (existsSync(schema)) files.push(schema);
  for (const file of files) {
    const text = readFileSync(file, 'utf8');
    for (const m of text.matchAll(/CREATE TABLE(?: IF NOT EXISTS)?\s+`?([A-Za-z0-9_]+)`?\s*\(([\s\S]*?)\)\s*ENGINE/g)) {
      const table = m[1].toLowerCase();
      if (!columns.has(table)) columns.set(table, new Set());
      for (const col of m[2].split(',')) {
        const name = (col.trim().split(/\s+/)[0] || '').replace(/`/g, '').toLowerCase();
        if (name) columns.get(table).add(name);
      }
      if (!fks.has(table)) fks.set(table, new Set());
      for (const r of m[2].matchAll(/REFERENCES\s+`?([A-Za-z0-9_]+)`?/gi)) {
        fks.get(table).add(r[1].toLowerCase());
      }
    }
    for (const m of text.matchAll(/ALTER TABLE\s+`?([A-Za-z0-9_]+)`?\s+ADD(?: COLUMN)?\s+`?([A-Za-z0-9_]+)`?/gi)) {
      const table = m[1].toLowerCase();
      if (!columns.has(table)) columns.set(table, new Set());
      columns.get(table).add(m[2].toLowerCase());
    }
  }
  return { columns, fks };
}

function tableLinked(table, businessTables, schemaIndex) {
  const cols = schemaIndex.columns.get(table) || new Set();
  const keys = [...cols].filter((c) => CORE_KEYS.has(c)).sort();
  const refs = [...(schemaIndex.fks.get(table) || new Set())].filter((t) => businessTables.has(t)).sort();
  return { keys, refs, linked: keys.length > 0 || refs.length > 0 };
}

function slug(s) {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

export function audit(rootDir = root) {
  const tier1 = loadJson(path.join(rootDir, 'manifest', 'tier1.json'));
  const linksData = loadJson(path.join(rootDir, 'manifest', 'tier1_links.json'));
  const businessTables = new Set((tier1.businessTables || []).map((t) => t.toLowerCase()));
  const moneyActions = new Set(tier1.moneyActions || []);
  const tier1Modules = new Set(tier1.tier1Modules || []);
  const schemaIndex = buildSchemaIndex(rootDir);
  const cobolDir = path.join(rootDir, 'cobol', 'src');

  const modules = (linksData.modules || []).filter((m) => m.linkageLevel === 'L2' || m.linkageLevel === 'L3');
  for (const mod of modules) {
    if (!mod.source) {
      console.error(`FAIL: tier1_links entry ${mod.module} has no source (regenerate the graph)`);
      process.exit(1);
    }
  }
  const items = [];
  const moduleStatus = {};

  for (const mod of modules) {
    const src = existsSync(path.join(cobolDir, mod.source))
      ? readFileSync(path.join(cobolDir, mod.source), 'utf8')
      : '';
    const paras = splitParagraphs(src);
    const actions = [...paras.entries()].filter(
      ([name]) => name !== 'MAIN-LOGIC' && (name.startsWith('ACTION-') || name.endsWith('-LOGIC')),
    );
    let open = 0;
    const push = (item) => {
      items.push(item);
      if (item.status === 'OPEN' || item.status === 'IN_PROGRESS') open += 1;
    };

    for (const [name, body] of actions) {
      const text = body.join('\n');
      const tables = tableRefs(text);
      const core = [...tables].filter((t) => businessTables.has(t)).sort();
      const calls = [...text.matchAll(/CALL\s+"([a-z_]+)"/g)].map((m) => m[1]).filter((c) => tier1Modules.has(c));
      const lits = [...text.matchAll(/"([A-Z][A-Z0-9_]{2,})"/g)].map((m) => m[1]).filter((a) => moneyActions.has(a));
      const identity = tables.has('users');
      if (core.length > 0 || calls.length > 0 || lits.length > 0 || identity) {
        continue; // CORE_LINKED
      }
      const writes = [...writeRefs(text)].filter((t) => !t.endsWith('_audit'));
      if (writes.length === 0) continue; // pure-read paragraph: exempt, listed in docs only
      const touched = [...tables].filter((t) => !isRefish(t) && !NOISE_TABLES.has(t)).sort();
      push({
        id: `${mod.module}:action:${slug(name)}`,
        module: mod.module,
        kind: 'action',
        subject: name,
        status: 'OPEN',
        reason: `Write paragraph with no core link (writes ${sortJoin(writes)})`,
        evidence: [`paragraph ${name}`, `touched tables: ${sortJoin(touched) || 'none'}`],
        owner: null,
      });
    }

    const allTables = tableRefs(src);
    const domainTables = [...allTables]
      .filter((t) => !businessTables.has(t) && !isRefish(t) && !t.endsWith('_audit') && !NOISE_TABLES.has(t))
      .sort();
    for (const table of domainTables) {
      const { keys, refs, linked } = tableLinked(table, businessTables, schemaIndex);
      if (linked) continue;
      const cols = schemaIndex.columns.get(table);
      push({
        id: `${mod.module}:table:${slug(table)}`,
        module: mod.module,
        kind: 'table',
        subject: table,
        status: 'OPEN',
        reason: `Domain table has no core business key or FK into a Tier-1 table`,
        evidence: [
          cols ? `columns: ${[...cols].sort().join(', ').slice(0, 400)}` : 'no DDL found in schema.sql/migrations',
          keys.length ? `core keys: ${keys.join(', ')}` : 'no core business-key columns',
          refs.length ? `core FK targets: ${refs.join(', ')}` : 'no FOREIGN KEY into Tier-1 tables',
        ],
        owner: null,
      });
    }

    if (!mod.hasTests) {
      push({
        id: `${mod.module}:route:no-test`,
        module: mod.module,
        kind: 'route',
        subject: 'integration test',
        status: 'OPEN',
        reason: 'No DB/table/integration test proves the Tier-1 link (auth/shape depth stays with existing gates)',
        evidence: [],
        owner: null,
      });
    }

    push({
      id: `${mod.module}:audit:core-reference`,
      module: mod.module,
      kind: 'audit',
      subject: 'audit core reference',
      status: 'OPEN',
      reason:
        'Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics',
      evidence: [],
      owner: null,
    });

    moduleStatus[mod.module] = open > 0 ? 'PARTIAL' : 'CONNECTED';
  }

  const summary = { CONNECTED: 0, PARTIAL: 0 };
  for (const m of modules) summary[moduleStatus[m.module]] += 1;
  return { items, moduleStatus, summary, modules: modules.map((m) => m.module) };
}

function sortJoin(arr) {
  return [...arr].sort().join(', ');
}

function renderDocs(auditResult) {
  const byModule = new Map();
  for (const item of auditResult.items) {
    if (!byModule.has(item.module)) byModule.set(item.module, []);
    byModule.get(item.module).push(item);
  }
  const openCount = auditResult.items.filter((i) => i.status === 'OPEN' || i.status === 'IN_PROGRESS').length;
  const modRows = [...auditResult.modules].sort().map((m) => {
    const n = (byModule.get(m) || []).length;
    return `| \`${m}\` | ${auditResult.moduleStatus[m]} | ${n} |`;
  });
  const itemRows = [...auditResult.items]
    .sort((a, b) => a.id.localeCompare(b.id))
    .map((i) => `| \`${i.id}\` | \`${i.module}\` | ${i.kind} | ${i.status} | ${i.owner || '—'} | ${i.reason} |`);
  return `# Integration Backlog

> Generated structure by \`scripts/check_integration_completion.mjs\`
> (\`--write\` only adds missing computed-OPEN items; it never modifies
> existing entries). Items close by wiring the missing link (no new
> features) or by WAIVED with an accepted-risk reason + owner. Pure-read
> paragraphs (paged LIST/GET/SUMMARY/AUDIT/VALIDATE with no writes) are
> exempt and not listed: a read needs no core link to be correct. Route
> auth/shape depth stays with check_route_auth and the field-order gate.

| Module status | Modules |
| --- | ---: |
| CONNECTED (no open items) | ${auditResult.summary.CONNECTED} |
| PARTIAL (open items) | ${auditResult.summary.PARTIAL} |

Open/in-progress items: ${openCount} of ${auditResult.items.length} recorded.

| Module | Status | Items |
| --- | --- | ---: |
${modRows.join('\n')}

| Item | Module | Kind | Status | Owner | Reason |
| --- | --- | --- | --- | --- | --- |
${itemRows.join('\n')}
`;
}

export { STATUS, KINDS };

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const backlogPath = path.join(root, 'manifest', 'integration_backlog.json');

  if (mode === 'write' || mode === 'write-docs') {
    let recorded = [];
    if (mode === 'write') {
      if (existsSync(backlogPath)) {
        recorded = JSON.parse(readFileSync(backlogPath, 'utf8')).items || [];
      }
      const have = new Set(recorded.map((i) => i.id));
      const fresh = audit(root);
      let added = 0;
      for (const item of fresh.items) {
        if (!have.has(item.id)) {
          recorded.push(item);
          added += 1;
        }
      }
      recorded.sort((a, b) => a.id.localeCompare(b.id));
      writeFileSync(
        backlogPath,
        `${JSON.stringify({ generatedAt: new Date().toISOString(), items: recorded }, null, 2)}\n`,
      );
      console.log(`Wrote ${backlogPath} (+${added} new, ${recorded.length} total)`);
    } else {
      recorded = JSON.parse(readFileSync(backlogPath, 'utf8')).items || [];
    }
    const fresh = audit(root);
    const byId = new Map(recorded.map((i) => [i.id, i]));
    const merged = fresh.items.map((i) => byId.get(i.id) || i);
    for (const r of recorded) {
      if (!fresh.items.some((i) => i.id === r.id) && (r.status === 'DONE' || r.status === 'WAIVED')) {
        merged.push(r);
      }
    }
    merged.sort((a, b) => a.id.localeCompare(b.id));
    writeFileSync(path.join(root, 'docs', 'INTEGRATION_BACKLOG.md'), renderDocs({ ...fresh, items: merged }));
    console.log(`Wrote docs/INTEGRATION_BACKLOG.md (${merged.length} items)`);
    process.exit(0);
  }

  if (!existsSync(backlogPath)) {
    console.error(
      'FAIL: manifest/integration_backlog.json missing (run scripts/check_integration_completion.mjs --write)',
    );
    process.exit(1);
  }
  const recorded = JSON.parse(readFileSync(backlogPath, 'utf8')).items || [];
  const failures = [];
  const byId = new Map(recorded.map((i) => [i.id, i]));
  const seen = new Set();
  for (const item of recorded) {
    for (const key of REQUIRED) {
      if (!(key in item)) failures.push(`${item.id || '?'}: missing field "${key}"`);
    }
    if (item.status && !STATUS.includes(item.status)) failures.push(`${item.id}: unknown status "${item.status}"`);
    if (item.kind && !KINDS.includes(item.kind)) failures.push(`${item.id}: unknown kind "${item.kind}"`);
    if (seen.has(item.id)) failures.push(`duplicate item: ${item.id}`);
    seen.add(item.id);
    if (!item.reason) failures.push(`${item.id}: missing reason`);
    if ((item.status === 'DONE' || item.status === 'WAIVED') && (!item.owner || (item.evidence || []).length === 0)) {
      failures.push(`${item.id}: ${item.status} requires owner + evidence`);
    }
  }
  const fresh = audit(root);
  const openIds = new Set(fresh.items.map((i) => i.id));
  for (const id of openIds) {
    if (!byId.has(id)) failures.push(`unlisted open item ${id} (add via --write after review)`);
  }
  for (const item of recorded) {
    if ((item.status === 'OPEN' || item.status === 'IN_PROGRESS') && !openIds.has(item.id)) {
      failures.push(`stale item ${item.id} (no longer computed; mark DONE/WAIVED with evidence or remove)`);
    }
  }
  if (failures.length) {
    for (const f of failures) console.error(`FAIL: ${f}`);
    process.exit(1);
  }
  const open = recorded.filter((i) => i.status === 'OPEN' || i.status === 'IN_PROGRESS').length;
  console.log(`OK: integration backlog holds ${recorded.length} items (${open} open); recompute matches`);
}
