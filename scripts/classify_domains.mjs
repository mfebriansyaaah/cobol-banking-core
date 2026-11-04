// Domain status registry (PR-010): explicit per-module disposition driven by
// Tier-1 linkage (PR-009), not by LOC or template similarity.
//
// Status meanings:
//   ACTIVE  - linked (L3) or Tier-3 utility; safe to refactor with equivalence.
//   PILOT   - L2: live but integration completion (PR-010E) still open.
//   REVIEW  - L1: manual review decides upgrade-to-L2 or dead-candidate.
//   FROZEN  - L0 or deprecated legacy: no refactor, no new routes; awaits
//             dead-candidate evidence (PR-010F) and retirement waves.
//   RETIRED - routes removed (set only by a retirement PR upon route removal).
//
// domain_status.json is hand-maintained once created: --write only ADDS
// missing modules with rule-based defaults and refreshes docs/DOMAIN_STATUS.md;
// it never modifies existing entries (owner/replacement/consumer decisions).
//
// Usage:
//   node scripts/classify_domains.mjs --check [--root DIR] (default)
//   node scripts/classify_domains.mjs --write [--root DIR]
//   node scripts/classify_domains.mjs --write-docs [--root DIR]
// Exit: 0 ok, 1 mismatch, 2 usage error.
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
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
    console.log('usage: classify_domains.mjs [--check|--write|--write-docs] [--root DIR]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}
root = path.resolve(root);

const STATUS = ['ACTIVE', 'PILOT', 'REVIEW', 'FROZEN', 'RETIRED'];
const REQUIRED = [
  'domain',
  'module',
  'routeFile',
  'table',
  'tier',
  'linkageLevel',
  'linkedCoreDomains',
  'replacement',
  'consumer',
  'trafficLastSeen',
  'owner',
  'status',
  'reason',
  'retireAfter',
  'tableDropDate',
];

// Deprecated legacy modules and their canonical replacements (README table +
// docs/domain_overview.md; tables are kept for compat, not extended).
const LEGACY = {
  collateral_mgmt_core: 'collateral_core',
  collateral_repossession_core: 'collateral_core',
  collateralized_core: 'collateral_core',
  trade_finance_core: 'letter_of_credit_core',
  documentary_credit_core: 'letter_of_credit_core',
  bankers_acceptance_core: 'letter_of_credit_core',
  export_finance_core: 'letter_of_credit_core',
  import_finance_core: 'letter_of_credit_core',
  factoring_core: 'letter_of_credit_core',
  tax_withholding_core: 'tax_management_core',
  tax_item_core: 'tax_management_core',
  dispute_management_core: 'chargeback_core',
  loyalty_program_core: 'loyalty_core',
  rewards_management_core: 'loyalty_core',
  points_redemption_core: 'loyalty_core',
  cashback_core: 'loyalty_core',
  asset_management_core: 'fixed_asset_core',
};

// Canonical adjacent domains (docs/domain_overview.md). Scoring may still say
// L0/L1 when the core link lives in orchestration rather than in the module's
// own SQL; PR-010E confirms the link or PR-010F retires the module.
const CANONICAL = new Set([
  'collateral_core',
  'letter_of_credit_core',
  'bank_guarantee_core',
  'merchant_core',
  'merchant_settlement_core',
  'tax_management_core',
  'chargeback_core',
  'payroll_processing_core',
  'fixed_asset_core',
  'loyalty_core',
]);

const TABLE_DOMAIN = [
  [/^(accounts|ledger|journal_entries)$/, 'wallet/ledger'],
  [/^loan_/, 'lending'],
  [/^deposit_/, 'deposits'],
  [/^card_/, 'cards'],
  [/^collection_/, 'collections'],
  [/^fee_/, 'fees'],
  [/^gl_/, 'accounting'],
];

function loadJson(p) {
  if (!existsSync(p)) {
    console.error(`FAIL: ${p} missing`);
    process.exit(1);
  }
  return JSON.parse(readFileSync(p, 'utf8'));
}

// Most-referenced own-domain table: excludes Tier-1 business tables,
// reference tables, audit tables, and SQL-noise tokens. Informational only;
// the linkage graph (not this field) decides status.
function primaryTable(rootDir, module) {
  const src = path.join(rootDir, 'cobol', 'src', `${module}.cob`);
  if (!existsSync(src)) return null;
  const text = readFileSync(src, 'utf8');
  const counts = new Map();
  for (const m of text.matchAll(/\b(?:FROM|JOIN|INTO|UPDATE)\s+`?([A-Za-z0-9_]+)`?/g)) {
    const t = m[1].toLowerCase();
    if (/^\d+$/.test(t)) continue;
    if (['ls', 'ws', 'when', 'set', 'values', 'into'].includes(t)) continue;
    if (t === 'users' || t === 'currencies' || t.startsWith('ref_') || t.endsWith('_audit')) continue;
    counts.set(t, (counts.get(t) ?? 0) + 1);
  }
  let best = null;
  let bestN = 0;
  for (const [t, n] of counts) {
    if (n > bestN) {
      best = t;
      bestN = n;
    }
  }
  return best;
}

function linkedCoreDomains(businessTables) {
  const out = new Set();
  for (const t of businessTables || []) {
    for (const [re, domain] of TABLE_DOMAIN) {
      if (re.test(t)) out.add(domain);
    }
  }
  return [...out].sort();
}

function defaultEntry(rootDir, link, tierOf) {
  const module = link.module;
  const domain = module.endsWith('_core') ? module.slice(0, -5) : module;
  const entry = {
    domain,
    module,
    routeFile: (link.routeFiles && link.routeFiles[0]) || null,
    table: primaryTable(rootDir, module),
    tier: tierOf(module),
    linkageLevel: link.linkageLevel,
    linkedCoreDomains: linkedCoreDomains(link.businessTables),
    replacement: LEGACY[module] || null,
    consumer: null,
    trafficLastSeen: null,
    owner: null,
    status: 'FROZEN',
    reason: '',
    retireAfter: null,
    tableDropDate: null,
  };
  if (LEGACY[module]) {
    entry.status = 'FROZEN';
    entry.reason =
      `Deprecated legacy clone; kept for compat, do not extend. Canonical replacement: ${LEGACY[module]}. ` +
      `Removal in PR-011..013; tables stay until one cycle after route removal.`;
    return entry;
  }
  const canonicalNote = CANONICAL.has(module)
    ? ' NOTE: canonical-adjacent per domain overview; confirm the orchestration link in PR-010E or retire in PR-010F.'
    : '';
  switch (link.linkageLevel) {
    case 'L3':
      entry.status = 'ACTIVE';
      entry.reason = 'Proven core-transaction link (or Tier-1 core). Refactor only with equivalence proof.';
      break;
    case 'L2':
      entry.status = 'PILOT';
      entry.reason = 'Business link proven; integration completion (PR-010E) still open before ACTIVE.';
      break;
    case 'L1':
      entry.status = 'REVIEW';
      entry.reason = 'Weak or untested link; manual review decides upgrade-to-L2 or dead-candidate.' + canonicalNote;
      break;
    case 'UTILITY':
      entry.status = 'ACTIVE';
      entry.reason = 'Tier-3 utility; never a retire candidate.';
      break;
    default:
      entry.status = 'FROZEN';
      entry.reason = 'No proven core link; frozen pending dead-candidate evidence (PR-010F).' + canonicalNote;
      break;
  }
  return entry;
}

function tierOfFactory(tier1) {
  const t1 = new Set(tier1.tier1Modules || []);
  const util = new Set(tier1.utilityModules || []);
  return (module) => {
    if (t1.has(module)) return 1;
    if (util.has(module)) return 3;
    return 2;
  };
}

function routeExists(rootDir, routeFile) {
  if (!routeFile) return false;
  return existsSync(path.join(rootDir, 'middleware', 'src', 'routes', routeFile));
}

function validate(rootDir, entries, links) {
  const failures = [];
  const byModule = new Map(entries.map((e) => [e.module, e]));
  for (const e of entries) {
    for (const key of REQUIRED) {
      if (!(key in e)) failures.push(`${e.module || '?'}: missing field "${key}"`);
    }
    if (e.status && !STATUS.includes(e.status)) failures.push(`${e.module}: unknown status "${e.status}"`);
    if (!e.reason) failures.push(`${e.module}: missing reason`);
  }
  const linkLevels = new Map(links.map((m) => [m.module, m.linkageLevel]));
  for (const m of links.map((x) => x.module)) {
    if (!byModule.has(m)) failures.push(`missing domain_status entry for module ${m}`);
  }
  for (const e of entries) {
    if (!linkLevels.has(e.module)) {
      failures.push(`domain_status lists unknown module ${e.module}`);
      continue;
    }
    if (e.linkageLevel !== linkLevels.get(e.module)) {
      failures.push(
        `${e.module}: linkageLevel ${e.linkageLevel} != tier1_links ${linkLevels.get(e.module)} (regenerate)`,
      );
    }
    if ((e.linkageLevel === 'L0' || e.linkageLevel === 'L1') && e.status === 'ACTIVE') {
      failures.push(`${e.module}: L0/L1 must not be ACTIVE (use REVIEW/FROZEN/RETIRED)`);
    }
    if (e.status === 'RETIRED') {
      if (e.routeFile && routeExists(rootDir, e.routeFile)) {
        failures.push(`${e.module}: RETIRED but route ${e.routeFile} still active (remove the route first)`);
      }
      if (!e.replacement) failures.push(`${e.module}: RETIRED requires a replacement`);
      if (!e.trafficLastSeen) failures.push(`${e.module}: RETIRED requires trafficLastSeen evidence`);
    }
  }
  return failures;
}

function renderDocs(entries) {
  const counts = {};
  for (const e of entries) counts[e.status] = (counts[e.status] ?? 0) + 1;
  const rows = [...entries]
    .sort((a, b) => a.module.localeCompare(b.module))
    .map(
      (e) =>
        `| \`${e.domain}\` | \`${e.module}\` | ${e.tier} | ${e.linkageLevel} | ${e.status} | ${e.routeFile || '—'} | ${e.table || '—'} | ${e.replacement ? `\`${e.replacement}\`` : '—'} | ${e.reason} |`,
    );
  return `# Domain Status

> Generated by \`scripts/classify_domains.mjs\` (entry defaults) with
> hand-maintained dispositions. \`--write\` only adds missing modules and
> refreshes this file; it never modifies existing entries. Review quarterly:
> linkage changes (PR-009), integration completion (PR-010E), and retirements
> (PR-010A..D) all land here.

| Status | Modules |
| --- | ---: |
${STATUS.map((s) => `| ${s} | ${counts[s] ?? 0} |`).join('\n')}

Status meanings: ACTIVE (linked, refactorable with equivalence), PILOT (L2,
integration completion open), REVIEW (L1, manual decision pending), FROZEN
(L0/deprecated, no refactor, awaits evidence), RETIRED (routes removed).

| Domain | Module | Tier | Link | Status | Route | Table | Replacement | Reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
${rows.join('\n')}
`;
}

export { STATUS, LEGACY, CANONICAL, defaultEntry, validate, renderDocs };

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const tier1 = loadJson(path.join(root, 'manifest', 'tier1.json'));
  const linksData = loadJson(path.join(root, 'manifest', 'tier1_links.json'));
  const links = linksData.modules || [];
  const statusPath = path.join(root, 'manifest', 'domain_status.json');

  if (mode === 'write' || mode === 'write-docs') {
    let entries = [];
    if (mode === 'write') {
      if (existsSync(statusPath)) {
        entries = JSON.parse(readFileSync(statusPath, 'utf8')).entries || [];
      }
      const have = new Set(entries.map((e) => e.module));
      const tierOf = tierOfFactory(tier1);
      let added = 0;
      for (const link of links) {
        if (!have.has(link.module)) {
          entries.push(defaultEntry(root, link, tierOf));
          added += 1;
        }
      }
      entries.sort((a, b) => a.module.localeCompare(b.module));
      writeFileSync(statusPath, `${JSON.stringify({ generatedAt: new Date().toISOString(), entries }, null, 2)}\n`);
      console.log(`Wrote ${statusPath} (+${added} new, ${entries.length} total)`);
    } else {
      entries = JSON.parse(readFileSync(statusPath, 'utf8')).entries || [];
    }
    writeFileSync(path.join(root, 'docs', 'DOMAIN_STATUS.md'), renderDocs(entries));
    console.log(`Wrote docs/DOMAIN_STATUS.md (${entries.length} entries)`);
    process.exit(0);
  }

  if (!existsSync(statusPath)) {
    console.error('FAIL: manifest/domain_status.json missing (run scripts/classify_domains.mjs --write)');
    process.exit(1);
  }
  const entries = JSON.parse(readFileSync(statusPath, 'utf8')).entries || [];
  const failures = validate(root, entries, links);
  if (failures.length) {
    for (const f of failures) console.error(`FAIL: ${f}`);
    process.exit(1);
  }
  const counts = {};
  for (const e of entries) counts[e.status] = (counts[e.status] ?? 0) + 1;
  console.log(`OK: ${entries.length} domain dispositions (${STATUS.map((s) => `${s} ${counts[s] ?? 0}`).join(', ')})`);
}
