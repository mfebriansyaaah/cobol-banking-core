// Table-of-contents generator for long hand-written docs.
// Convention: files that opt in carry a marker pair; everything between
// them is regenerated from ## / ### headings (GitHub-style anchors).
// Usage: node scripts/docs_toc.mjs [--write] [--check] [ROOT]
import { existsSync, readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const BEGIN = '<!-- BEGIN GENERATED TOC -->';
const END = '<!-- END GENERATED TOC -->';

// GitHub heading-anchor algorithm (github-slugger): lowercase, strip
// punctuation (underscores and hyphens survive), then every space becomes
// one hyphen (runs are NOT collapsed, so "a + b" slugifies to "a--b").
// The ASCII punctuation class is a regex literal; the two non-ASCII
// punctuation blocks are built from code points so this file stays ASCII.
const ASCII_PUNCT = /['!"#$%&()*+,./:;<=>?@[\]^`{|}~]/g;
const BLOCK_PUNCT = (() => {
  let chars = '';
  for (let c = 0x2000; c <= 0x206f; c += 1) chars += String.fromCharCode(c);
  for (let c = 0x2e00; c <= 0x2e7f; c += 1) chars += String.fromCharCode(c);
  return new RegExp('[' + chars + ']', 'g');
})();
function slug(text) {
  return text.toLowerCase().replace(ASCII_PUNCT, '').replace(BLOCK_PUNCT, '').replace(/ /g, '-');
}

function tocFor(text) {
  const lines = [];
  for (const m of text.matchAll(/^(#{2,3})\s+(.+?)\s*$/gm)) {
    const indent = m[1] === '###' ? '  ' : '';
    lines.push(`${indent}- [${m[2]}](#${slug(m[2])})`);
  }
  return lines.join('\n');
}

export function renderDocWithToc(text) {
  const si = text.indexOf(BEGIN);
  const ei = text.indexOf(END);
  if (si === -1 || ei === -1 || ei < si) return null; // not opted in
  const before = text.slice(0, si).replace(/\s+$/, '');
  const after = text.slice(ei + END.length).replace(/^\s+/, '');
  const toc = tocFor(text);
  return `${before}\n\n${BEGIN}\n\n${toc}\n\n${END}\n\n${after}`;
}

function* walk(dir) {
  if (!existsSync(dir)) return;
  for (const e of readdirSync(dir)) {
    const p = path.join(dir, e);
    const st = statSync(p);
    if (st.isDirectory()) yield* walk(p);
    else if (e.endsWith('.md')) yield p;
  }
}

export function tocStaleFiles(rootDir) {
  const docsDir = path.join(rootDir, 'docs');
  const dirty = [];
  for (const f of walk(docsDir)) {
    const rel = path.relative(docsDir, f);
    if (rel.startsWith('archive' + path.sep)) continue;
    const text = readFileSync(f, 'utf8');
    if (!text.includes(BEGIN)) continue;
    if (renderDocWithToc(text) !== text) dirty.push(path.relative(rootDir, f));
  }
  return dirty;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
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

  const dirty = tocStaleFiles(root);
  if (write && dirty.length) {
    for (const f of dirty)
      writeFileSync(path.join(root, f), renderDocWithToc(readFileSync(path.join(root, f), 'utf8')));
    console.log(`Wrote ToC in: ${dirty.join(', ')}`);
  } else if (write) {
    console.log('ToCs already current');
  }
  if (check && dirty.length) {
    console.error('Stale table of contents in:');
    for (const f of dirty) console.error(`  - ${f}; run \`node scripts/docs_toc.mjs --write\``);
    process.exit(1);
  }
  if (!write && !check && dirty.length) {
    console.log(`Stale ToC in: ${dirty.join(', ')} (run with --write to fix)`);
  }
}
