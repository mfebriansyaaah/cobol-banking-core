// Module size ratchet (audit A-08): prevent unbounded growth, not a refactor.
// Limits are set just above current maxima so the gate only fires on growth.
// Usage: node scripts/check_module_size.mjs [root]
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { findParagraphs } from './lib/cobol_paragraphs.mjs';

const ROOT = path.resolve(process.argv[2] || '.');
const LIMITS = { cobolModule: 1700, cobolParagraph: 650, srcJs: 500, testJs: 2500, scriptJs: 650 };
const failures = [];

function lines(file) {
  const text = readFileSync(file, 'utf8');
  return text.split('\n').length - (text.endsWith('\n') ? 1 : 0);
}

function walkJs(dir, out = []) {
  if (!existsSync(dir)) return out;
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walkJs(p, out);
    else if (e.name.endsWith('.js') || e.name.endsWith('.mjs')) out.push(p);
  }
  return out;
}

for (const f of readdirSync(path.join(ROOT, 'cobol', 'src')).filter((x) => x.endsWith('.cob'))) {
  const file = path.join(ROOT, 'cobol', 'src', f);
  const n = lines(file);
  if (n > LIMITS.cobolModule) failures.push(`${file}: ${n} > ${LIMITS.cobolModule}`);
  for (const p of findParagraphs(readFileSync(file, 'utf8'))) {
    if (p.body.length > LIMITS.cobolParagraph) {
      failures.push(`${file}:${p.name}: ${p.body.length} > ${LIMITS.cobolParagraph}`);
    }
  }
}

for (const [dir, limit] of [
  [path.join(ROOT, 'middleware', 'src'), LIMITS.srcJs],
  [path.join(ROOT, 'middleware', 'test'), LIMITS.testJs],
  [path.join(ROOT, 'scripts'), LIMITS.scriptJs],
]) {
  for (const file of walkJs(dir)) {
    const n = lines(file);
    if (n > limit) failures.push(`${path.relative(ROOT, file)}: ${n} > ${limit}`);
  }
}

if (failures.length) {
  for (const f of failures) console.error(`FAIL: ${f}`);
  process.exit(1);
}
console.log('OK: module size ratchet holds');
