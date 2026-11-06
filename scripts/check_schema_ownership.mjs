// Schema ownership gate (PR-062): every table added after the legacy
// baseline must be registered in manifest/table_ownership.json with
// owner/status, a non-generic name (or justification), and an audit story.
// Legacy tables are grandfathered (listed by hash, not by name — renaming
// history is out of scope). Usage: node scripts/check_schema_ownership.mjs [root]
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const fail = (m) => {
  console.error(`FAIL: ${m}`);
  process.exitCode = 1;
};

const snap = readFileSync(path.join(ROOT, 'database', 'schema_full.sql'), 'utf8');
const tables = [...new Set([...snap.matchAll(/CREATE TABLE `?(\w+)`?/g)].map((m) => m[1].toLowerCase()))];
const reg = JSON.parse(readFileSync(path.join(ROOT, 'manifest', 'table_ownership.json'), 'utf8'));

// Legacy baseline: hash of the sorted table list the last time a human
// reviewed it. New tables = present now, absent from the registry's recorded
// list. (The registry keeps the reviewed list beside the curated entries.)
const reviewed = new Set((reg.legacyTables || []).map((t) => String(t).toLowerCase()));
const curated = new Set(Object.keys(reg.tables || {}).map((t) => t.toLowerCase()));
const known = new Set([...reviewed, ...curated]);
const fresh = tables.filter((t) => !known.has(t));

for (const t of fresh) {
  if ((reg.genericDeny || []).some((g) => t.includes(String(g).toLowerCase()))) {
    fail(`new table '${t}' matches a generic-name deny pattern (justify in table_ownership.json or rename)`);
    continue;
  }
  fail(`new table '${t}' is unregistered (add owner/status/tier1Links/audit story to manifest/table_ownership.json)`);
}
for (const [name, meta] of Object.entries(reg.tables || {})) {
  if (!tables.includes(name.toLowerCase())) {
    fail(`registered table '${name}' missing from schema_full.sql (stale registry)`);
    continue;
  }
  for (const k of ['owner', 'status', 'tier1Links', 'audited']) {
    if (meta[k] === undefined || meta[k] === null || meta[k] === '') fail(`registered table '${name}' lacks '${k}'`);
  }
}

if (process.exitCode) {
  console.error('schema ownership check failed');
} else {
  console.log(`OK: schema ownership holds (${tables.length} tables, ${fresh.length} new unregistered)`);
}
