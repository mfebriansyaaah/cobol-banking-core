// COBOL field-size gate (ADR-0006): the C bridge copies queries into
// fixed buffers — WS-PREP-SQL into 1024 bytes, WS-QUERY (SET_QUERY) into
// 512 bytes — and truncates silently beyond that. A truncated query executes
// a different statement than the author wrote.
//   - WS-PREP-SQL declarations must be PIC X(n<=1024).
//   - WS-QUERY declarations must be PIC X(n<=512).
//   - Literal query text (MOVE "..." and STRING blocks into either buffer)
//     must total <=1023 bytes (leaves room for the C NUL terminator).
// Bind values travel separately (max 256 each) and are unaffected.
// Usage: node scripts/check_cobol_field_sizes.mjs [root]
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const SRC = path.join(ROOT, 'cobol', 'src');

const failures = [];
let checked = 0;

function lineno(src, idx) {
  return src.slice(0, idx).split('\n').length;
}

for (const f of readdirSync(SRC)
  .filter((x) => x.endsWith('.cob'))
  .sort()) {
  const raw = readFileSync(path.join(SRC, f), 'utf8');
  // Strip full-line comments. (Inline *> comments are left alone: query
  // literals never contain *>, and comment text without quotes cannot
  // inflate the literal sums below.)
  const src = raw
    .split('\n')
    .filter((ln) => !ln.trimStart().startsWith('*>'))
    .join('\n');
  checked += 1;

  for (const m of src.matchAll(/01\s+WS-PREP-SQL\s+PIC\s+X\((\d+)\)/g)) {
    if (Number(m[1]) > 1024)
      failures.push(`${f}:${lineno(src, m.index)}: WS-PREP-SQL PIC X(${m[1]}) exceeds 1024 (C buffer)`);
  }
  for (const m of src.matchAll(/01\s+WS-QUERY\s+PIC\s+X\((\d+)\)/g)) {
    if (Number(m[1]) > 512)
      failures.push(`${f}:${lineno(src, m.index)}: WS-QUERY PIC X(${m[1]}) exceeds 512 (C buffer)`);
  }
  for (const m of src.matchAll(/MOVE\s+"((?:[^"]|"")*)"\s+TO\s+WS-(?:PREP-SQL|QUERY)/g)) {
    const len = m[1].replace(/""/g, '"').length;
    if (len > 1023) failures.push(`${f}:${lineno(src, m.index)}: query literal ${len} bytes exceeds 1023`);
  }
  for (const m of src.matchAll(/\bSTRING\b(.*?)END-STRING/gs)) {
    const block = m[1];
    if (!/INTO\s+WS-(?:PREP-SQL|QUERY)/.test(block)) continue;
    let total = 0;
    for (const lm of block.matchAll(/"((?:[^"]|"")*)"/g)) total += lm[1].replace(/""/g, '"').length;
    if (total > 1023) failures.push(`${f}:${lineno(src, m.index)}: STRING-built query ~${total} bytes exceeds 1023`);
  }
}

if (failures.length) {
  console.error('COBOL FIELD SIZE VIOLATIONS (ADR-0006):');
  for (const m of failures) console.error(`  ${m}`);
  process.exit(1);
}

console.log(`OK: field sizes hold (${checked} modules, queries fit the C buffers)`);
