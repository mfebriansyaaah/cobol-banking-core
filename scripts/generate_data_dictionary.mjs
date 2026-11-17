// Data dictionary generator: renders docs/DATA_DICTIONARY.md from
// database/schema.sql (one section per table, alphabetical within each
// domain group). Numbers that a script can compute are computed, committed
// and gated (ADR-0007); run with --write after a schema change and let
// scripts/check_docs.mjs verify the file is fresh.
//
// Usage: node scripts/generate_data_dictionary.mjs [--write] [--check] [ROOT]
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
let write = false;
let check = false;
for (const a of args) {
  if (a === '--write') write = true;
  else if (a === '--check') check = true;
  else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else root = a;
}
root = path.resolve(root);

const SECOND_TOKENS = new Set(['NOT', 'NULL', 'DEFAULT', 'AUTO_INCREMENT', 'PRIMARY', 'UNIQUE']);
const CONSTRAINT_LEADERS = new Set([
  'PRIMARY',
  'KEY',
  'CONSTRAINT',
  'FOREIGN',
  'REFERENCES',
  'UNIQUE',
  'CHECK',
  'FULLTEXT',
  'SPATIAL',
  'INDEX',
  'PERIOD',
]);

function parseSchema(text) {
  const tables = [];
  const re = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?([A-Za-z0-9_]+)`?\s*\(/gi;
  let m;
  while ((m = re.exec(text)) !== null) {
    const name = m[1];
    // Find the matching close paren of the column list, paren-aware
    // (ENUM/SET args and nested function defaults contain parens).
    let depth = 0;
    let start = -1;
    const body = [];
    for (let i = m.index + m[0].length - 1; i < text.length; i += 1) {
      const ch = text[i];
      if (ch === '(') {
        if (depth === 0) start = i + 1;
        depth += 1;
      } else if (ch === ')') {
        depth -= 1;
        if (depth === 0) {
          body.push(text.slice(start, i));
          break;
        }
      }
    }
    const columns = [];
    for (const raw of (body[0] ?? '').split('\n')) {
      const line = raw.trim().replace(/,$/, '');
      if (!line || line.startsWith('--')) continue;
      const first = line.split(/\s+/, 1)[0].replace(/`/g, '').toUpperCase();
      if (CONSTRAINT_LEADERS.has(first)) continue;
      const cm = line.match(/^`?([A-Za-z0-9_]+)`?\s+(.*)$/);
      if (!cm) continue;
      const [, colName, rest] = cm;
      const tm = rest.match(/^([A-Za-z0-9_]+(?:\([^)]*\))?)\s*(.*)$/);
      if (!tm) continue;
      const [, typeTok, tail] = tm;
      const second = (tail.split(/\s+/, 1)[0] || '').toUpperCase();
      const cell = SECOND_TOKENS.has(second) ? `${typeTok} ${second}` : typeTok;
      columns.push({ name: colName, type: cell });
    }
    tables.push({ name, columns });
  }
  return tables;
}

export function generateDataDictionary(rootDir = root) {
  const schemaPath = path.join(rootDir, 'database', 'schema.sql');
  if (!existsSync(schemaPath)) {
    throw new Error(`missing database/schema.sql under ${rootDir}`);
  }
  const tables = parseSchema(readFileSync(schemaPath, 'utf8'));
  const groups = new Map();
  for (const t of tables) {
    const key = t.name.includes('_') ? t.name.split('_', 1)[0] : t.name;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(t);
  }
  const out = [];
  out.push('# Data Dictionary \u2014 cobol_db', '');
  out.push(`Generated from \`database/schema.sql\` (baseline). ${tables.length} tables.`, '', '');
  for (const key of [...groups.keys()].sort()) {
    out.push(`## Domain group: \`${key}_*\``, '', '');
    for (const t of groups.get(key).sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0))) {
      out.push(`### \`${t.name}\``, '', '| Column | Type |', '|---|---|');
      for (const c of t.columns) out.push(`| ${c.name} | ${c.type} |`);
      out.push('');
    }
  }
  return `${out.join('\n').replace(/\n+$/, '')}\n`;
}

if (write || check) {
  const expected = generateDataDictionary(root);
  const docPath = path.join(root, 'docs', 'DATA_DICTIONARY.md');
  const actual = existsSync(docPath) ? readFileSync(docPath, 'utf8') : null;
  if (actual === expected) {
    console.log('OK: docs/DATA_DICTIONARY.md matches database/schema.sql');
  } else if (check) {
    console.error('docs/DATA_DICTIONARY.md is stale; run `node scripts/generate_data_dictionary.mjs --write`');
    process.exit(1);
  } else {
    writeFileSync(docPath, expected);
    console.log(`Wrote ${path.relative(process.cwd(), docPath)}`);
  }
}
