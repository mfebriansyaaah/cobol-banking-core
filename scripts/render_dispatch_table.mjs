// Dispatch table renderer (PR-051): cobol/copy/dispatch_table.cpy generated
// from the action registry (slot order authoritative). main_logic.cob keeps
// only `COPY "dispatch_table.cpy".` — hand-editing the table is over.
// Usage: node scripts/render_dispatch_table.mjs [--write]
import { readFileSync, writeFileSync } from 'node:fs';

const ROOT = new URL('..', import.meta.url).pathname.replace(/\/$/, '');
const WRITE = process.argv.includes('--write');
const OUT = `${ROOT}/cobol/copy/dispatch_table.cpy`;

const registry = JSON.parse(readFileSync(`${ROOT}/manifest/actions.json`, 'utf8'));
const slots = [...(registry.dispatch || [])].sort((a, b) => a.slot - b.slot);
if (!slots.length) {
  console.error('registry has no dispatch section: run scripts/build_action_registry.mjs --write first');
  process.exit(1);
}
for (let i = 0; i < slots.length; i++) {
  if (slots[i].slot !== i + 1) {
    console.error(`dispatch slots not contiguous at index ${i} (slot ${slots[i].slot})`);
    process.exit(1);
  }
}

const lines = [`            MOVE ${slots.length} TO DISPATCH-COUNT.`];
for (const s of slots) {
  lines.push(
    `            MOVE "${s.prefix}" TO D-PREFIX(${s.slot}).`,
    `            MOVE ${s.prefixLen} TO D-PREFIX-LEN(${s.slot}).`,
    `            MOVE "${s.program}" TO D-PROGRAM(${s.slot}).`,
  );
}
const rendered = `${lines.join('\n')}\n`;

if (!WRITE) {
  let current = null;
  try {
    current = readFileSync(OUT, 'utf8');
  } catch {
    console.error('dispatch copybook missing: run scripts/render_dispatch_table.mjs --write');
    process.exit(1);
  }
  if (current !== rendered) {
    console.error('dispatch copybook drifted: run scripts/render_dispatch_table.mjs --write and review the diff');
    process.exit(1);
  }
  console.log(`OK: dispatch copybook in sync (${slots.length} slots)`);
} else {
  writeFileSync(OUT, rendered);
  console.log(`wrote ${OUT}: ${slots.length} slots`);
}
