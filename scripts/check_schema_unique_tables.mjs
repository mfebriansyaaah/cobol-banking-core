// Schema unique-table gate (audit P0-04): fail on duplicate CREATE TABLE
// definitions in database/schema.sql. Duplicates are silent because of
// CREATE TABLE IF NOT EXISTS, so the first definition wins and the second
// is dead weight.
// Usage:
//   node scripts/check_schema_unique_tables.mjs --check [--root DIR]
//   node scripts/check_schema_unique_tables.mjs --write [--root DIR]
// Exit: 0 ok, 1 duplicates on --check, 2 --write found differing blocks.
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let mode = 'check';
let root = '.';
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--check') mode = 'check';
  else if (a === '--write') mode = 'write';
  else if (a === '--root') {
    root = args[i + 1] ?? root;
    i += 1;
  } else if (!a.startsWith('--')) {
    root = a;
  } else {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  }
}
root = path.resolve(root);

const schemaPath = path.join(root, 'database', 'schema.sql');
const text = readFileSync(schemaPath, 'utf8');
const lines = text.split('\n');

const blocks = [];
for (let i = 0; i < lines.length; i += 1) {
  const m = lines[i].match(/^CREATE TABLE(?: IF NOT EXISTS)? `?([A-Za-z0-9_]+)`?/);
  if (!m) continue;
  const name = m[1];
  const start = i + 1;
  let end = -1;
  for (let j = i; j < lines.length; j += 1) {
    if (/^\) ENGINE=InnoDB;/.test(lines[j])) {
      end = j + 1;
      break;
    }
  }
  if (end === -1) {
    console.error(`FAIL: ${name} at line ${start} has no closing ") ENGINE=InnoDB;"`);
    process.exit(2);
  }
  blocks.push({ name, start, end, text: lines.slice(i, end).join('\n') });
  i = end - 1;
}

const byName = new Map();
for (const b of blocks) {
  if (!byName.has(b.name)) byName.set(b.name, []);
  byName.get(b.name).push(b);
}

const dups = [...byName.entries()].filter(([, v]) => v.length > 1);

if (mode === 'check') {
  if (!dups.length) {
    console.log(`OK: ${byName.size} unique table(s)`);
    process.exit(0);
  }
  for (const [name, v] of dups.sort((a, b) => a[0].localeCompare(b[0]))) {
    console.error(`DUPLICATE ${name}: lines ${v.map((b) => b.start).join(', ')}`);
  }
  process.exit(1);
}

// --write: dedupe byte-identical blocks, refuse differing blocks.
let removed = 0;
const removeLines = new Set();
for (const [name, v] of dups) {
  const first = v[0].text;
  const allSame = v.every((b) => b.text === first);
  if (!allSame) {
    console.error(
      `FAIL: ${name} has differing definitions at lines ${v.map((b) => b.start).join(', ')}; refusing to dedupe`,
    );
    process.exit(2);
  }
  for (let k = 1; k < v.length; k += 1) {
    for (let ln = v[k].start - 1; ln < v[k].end; ln += 1) removeLines.add(ln);
    removed += 1;
  }
}

if (!removed) {
  console.log(`OK: ${byName.size} unique table(s)`);
  process.exit(0);
}

const kept = lines.filter((_, idx) => !removeLines.has(idx));
writeFileSync(schemaPath, `${kept.join('\n')}${kept[kept.length - 1] === '' ? '' : '\n'}`);
console.log(`OK: removed ${removed} duplicate block(s), ${byName.size} unique table(s)`);
