#!/usr/bin/env node
// Generate a cutover migration for a batch of generated reference entities.
// Usage: node scripts/gen_cutover.mjs --batch 0092 --codes CUR,CHN,BRN
// Reads data/entities.json and emits database/migrations/<batch>_cutover.sql
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const args = process.argv.slice(2);
const batch = args[args.indexOf('--batch') + 1];
const codes = args[args.indexOf('--codes') + 1].split(',');

const data = JSON.parse(fs.readFileSync(path.join(root, 'data/entities.json'), 'utf8'));
const entities = data.entities.filter((e) => codes.includes(e.code));
if (entities.length !== codes.length) {
  const found = entities.map((e) => e.code);
  console.error('missing entities:', codes.filter((c) => !found.includes(c)));
  process.exit(1);
}

function snake(s) { return s.replace(/([A-Z])/g, '_$1').toLowerCase().replace(/^_/, ''); }
// entity name is already snake-ish (currency, cost_center); use as-is for type_code

let sql = `-- Gradual cutover batch: ${codes.join(', ')}.\n-- Migrates legacy generated reference rows into the generic ref_engine.\n-- Legacy tables remain as a read-only safety copy.\n\n`;

for (const e of entities) {
  const type = e.name;
  const table = e.table;
  const keyCol = e.key.column;
  const labelCol = e.label.column;
  const numCol = e.number.column;
  const flagCol = e.flag.column;
  const label = type.charAt(0).toUpperCase() + type.slice(1).replace(/_/g, ' ');

  sql += `-- ${type} (${e.code})\n`;
  sql += `INSERT IGNORE INTO ref_type (type_code, label, description, is_active) VALUES\n`;
  sql += `('${type}', '${label}', 'Cut over from ${table}', TRUE);\n\n`;

  sql += `INSERT IGNORE INTO ref_value (type_code, code)\n`;
  sql += `SELECT '${type}', ${keyCol} FROM ${table};\n\n`;

  sql += `INSERT IGNORE INTO ref_value_version\n`;
  sql += `    (ref_value_id, version_no, label, attributes, status, effective_from, approved_by, approved_at)\n`;
  sql += `SELECT v.id, 1, t.${labelCol},\n`;
  sql += `       CONCAT('num_val=', t.${numCol}, ';active=', t.${flagCol}),\n`;
  sql += `       IF(t.${flagCol}, 'ACTIVE', 'RETIRED'),\n`;
  sql += `       CURDATE(), 'migration', NOW()\n`;
  sql += `FROM ref_value v\n`;
  sql += `JOIN ${table} t ON t.${keyCol} = v.code\n`;
  sql += `WHERE v.type_code = '${type}'\n`;
  sql += `  AND NOT EXISTS (SELECT 1 FROM ref_value_version vv WHERE vv.ref_value_id = v.id);\n\n`;

  sql += `INSERT IGNORE INTO ref_engine_audit (type_code, value_code, action, actor_email, detail)\n`;
  sql += `SELECT '${type}', t.${keyCol}, 'CUTOVER', 'migration', 'from ${table}'\n`;
  sql += `FROM ${table} t\n`;
  sql += `WHERE NOT EXISTS (\n`;
  sql += `    SELECT 1 FROM ref_engine_audit a\n`;
  sql += `    WHERE a.type_code = '${type}' AND a.value_code = t.${keyCol} AND a.action = 'CUTOVER'\n`;
  sql += `);\n\n`;
}

const outPath = path.join(root, 'database/migrations', `${batch}_cutover.sql`);
fs.writeFileSync(outPath, sql);
console.log('wrote', outPath, 'for', entities.length, 'entities');
