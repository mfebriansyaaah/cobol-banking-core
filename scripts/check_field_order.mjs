// Thin wrapper so CI and run_gates have a stable check name.
// See scripts/generate_field_order.mjs for the contract documentation.
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.argv[2] || '.';
const gen = path.join(path.dirname(fileURLToPath(import.meta.url)), 'generate_field_order.mjs');
const r = spawnSync(process.execPath, [gen, '--check', root], { stdio: 'inherit' });
process.exit(r.status ?? 2);
