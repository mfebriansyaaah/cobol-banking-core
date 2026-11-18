// COBOL paragraph-length ratchet (Phase 2).
//
// Long paragraphs are the COBOL equivalent of a god function: they combine
// validation, SQL, accounting legs, and error mapping in one untestable unit.
// The Phase 2 gate caps a paragraph at 220 non-comment body lines. The two
// former 370+ line money paragraphs were split; new code must stay below the
// cap, and an existing paragraph may not grow past it.
//
// Usage: node scripts/check_cobol_paragraphs.mjs [root]
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const MAX_LINES = 220;
const SKIP = /^(END-|ELSE$|WHEN$|EXIT$|CONTINUE$|GOBACK$|STOP$|ENTRY$|PROCEDURE$)/;
const LABEL = /^\s{4,14}([A-Z][A-Z0-9_-]+)\.\s*$/;

export function paragraphLengths(source) {
  const lines = source.split('\n');
  const start = lines.findIndex((l) => l.toUpperCase().includes('PROCEDURE DIVISION'));
  if (start < 0) return [];
  const out = [];
  let current = null;
  let count = 0;
  const flush = () => {
    if (current) out.push({ name: current, lines: count });
  };
  for (const line of lines.slice(start + 1)) {
    const label = line.match(LABEL);
    if (label && !SKIP.test(label[1]) && !label[1].startsWith('END-')) {
      flush();
      current = label[1];
      count = 0;
      continue;
    }
    if (!current) continue;
    const code = line.split('*>')[0];
    if (code.trim() === '') continue;
    count += 1;
  }
  flush();
  return out;
}

export function check(rootDir) {
  const dir = path.join(rootDir, 'cobol', 'src');
  const errors = [];
  let checked = 0;
  for (const file of readdirSync(dir)
    .filter((f) => f.endsWith('.cob'))
    .sort()) {
    for (const para of paragraphLengths(readFileSync(path.join(dir, file), 'utf8'))) {
      checked += 1;
      if (para.lines > MAX_LINES) errors.push(`${file}: ${para.name} has ${para.lines} lines (max ${MAX_LINES})`);
    }
  }
  return { checked, errors };
}

function main(argv) {
  const rootDir = path.resolve(argv[0] || path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..'));
  const { checked, errors } = check(rootDir);
  if (errors.length > 0) {
    for (const err of errors) console.error(`FAIL: ${err}`);
    return 1;
  }
  console.log(`OK: ${checked} COBOL paragraph(s) are <= ${MAX_LINES} lines`);
  return 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
