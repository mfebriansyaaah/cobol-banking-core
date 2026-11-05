// Copybook inclusion-graph gate (PR-020): the copybook estate must stay
// tight — every .cpy included, every paragraph reachable, every WS var
// referenced in code (comments don't count). Counts live in
// tests/copybook_baseline.txt; the gate fails on drift with exact numbers.
// An 01 that owns live 88-levels counts as used via its children.
// Usage: node scripts/check_copybooks.mjs [--write] [ROOT]
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
let write = false;
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--write') write = true;
  else if (a === '--help' || a === '-h') {
    console.log('usage: check_copybooks.mjs [--write] [ROOT]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else root = a;
}
root = path.resolve(root);

const copyDir = path.join(root, 'cobol', 'copy');
const srcDir = path.join(root, 'cobol', 'src');
const baseFile = path.join(root, 'tests', 'copybook_baseline.txt');

const codeOnly = (s) =>
  s
    .split('\n')
    .filter((l) => !l.trim().startsWith('*>'))
    .join('\n');
const load = (p) => (existsSync(p) ? readFileSync(p, 'utf8') : '');

const cpyFiles = existsSync(copyDir)
  ? readdirSync(copyDir)
      .filter((f) => f.endsWith('.cpy'))
      .sort()
  : [];
const cobolFiles = existsSync(srcDir)
  ? readdirSync(srcDir)
      .filter((f) => f.endsWith('.cob'))
      .sort()
  : [];
const allSrc = new Map();
for (const f of cpyFiles) allSrc.set(`copy/${f}`, codeOnly(load(path.join(copyDir, f))));
for (const f of cobolFiles) allSrc.set(`src/${f}`, codeOnly(load(path.join(srcDir, f))));

// 1. Every copybook included at least once (COPY "name.cpy").
const orphans = cpyFiles.filter((f) => ![...allSrc.values()].some((s) => s.includes(`COPY "${f}"`)));

// 2. Every paragraph defined in a copybook PERFORMed from somewhere
// (transitively live: reached paragraphs keep their callees alive).
const paraDef = new Map();
for (const [file, src] of allSrc) {
  if (!file.startsWith('copy/')) continue;
  for (const m of src.matchAll(/^\s{7,8}([A-Z][A-Z0-9-]+)\./gm)) {
    if (!paraDef.has(m[1])) paraDef.set(m[1], file);
  }
}
const performed = new Set();
for (const s of allSrc.values()) {
  for (const m of s.matchAll(/PERFORM\s+([A-Z][A-Z0-9-]+)(?![A-Z0-9-])/g)) performed.add(m[1]);
}
const deadParas = [...paraDef.keys()].filter((p) => !performed.has(p));

// 2b. Inline-duplication ratchet (PR-021 rollout): paragraphs with a shared
// copybook must not gain new inline copies. Counts inline definitions of
// the extracted paragraphs across src modules; must only shrink.
const EXTRACTED = ['TRIM-VALUE', 'TRIM-ALL', 'VALIDATE-COUNT-FIELD'];
const inlineDupes = {};
for (const name of EXTRACTED) {
  let n = 0;
  for (const [file, src] of allSrc) {
    if (!file.startsWith('src/')) continue;
    const re = new RegExp(`^\\s{7}${name}\\.(?=\\s|$)`, 'gm');
    n += [...src.matchAll(re)].length;
  }
  inlineDupes[`inline_${name.toLowerCase().replace(/-/g, '_')}`] = n;
}

// 3. Every 01 WS var referenced in code; 88-levels count for their parents.
const wsVars = [];
for (const [file, src] of allSrc) {
  if (!file.startsWith('copy/')) continue;
  for (const m of src.matchAll(/^\s+01\s+([A-Z][A-Z0-9-]+)\s/gm)) wsVars.push({ name: m[1], file });
}
// Map each 88 to its parent 01 within copybook WS sources.
const parentOf88 = new Map();
for (const [file, src] of allSrc) {
  if (!file.startsWith('copy/')) continue;
  let cur = null;
  for (const line of src.split('\n')) {
    let m = line.match(/^\s+01\s+([A-Z][A-Z0-9-]+)\s/);
    if (m) cur = m[1];
    m = line.match(/^\s+88\s+([A-Z][A-Z0-9-]+)\s/);
    if (m && cur) parentOf88.set(m[1], cur);
  }
}
const deadVars = [];
for (const { name, file } of wsVars) {
  let used = false;
  for (const s of allSrc.values()) {
    for (const m of s.matchAll(new RegExp(`\\b${name}\\b`, 'g'))) {
      const lineNo = s.slice(0, m.index).split('\n').length - 1;
      const line = s.split('\n')[lineNo];
      if (new RegExp(`^\\s+01\\s+${name}\\s`).test(line)) continue; // own definition
      used = true;
      break;
    }
    if (used) break;
  }
  if (!used) {
    // An 01 owning referenced 88-levels is used via its children.
    const childUsed = [...parentOf88.entries()].some(
      ([c88, parent]) => parent === name && [...allSrc.values()].some((s) => new RegExp(`\\b${c88}\\b`).test(s)),
    );
    if (!childUsed) deadVars.push(`${name} (${file})`);
  }
}

const actual = {
  files: cpyFiles.length,
  paragraphs: paraDef.size,
  vars: wsVars.length,
  ...inlineDupes,
};
let want = null;
if (existsSync(baseFile)) {
  want = {};
  for (const line of load(baseFile).split('\n')) {
    const m = line.match(/^(\w+)=(\d+)$/);
    if (m) want[m[1]] = Number(m[2]);
  }
}

const details = [
  ...orphans.map((f) => `orphan copybook: copy/${f}`),
  ...deadParas.map((p) => `dead paragraph: ${p} (${paraDef.get(p)})`),
  ...deadVars.map((v) => `dead var: ${v}`),
];

if (write) {
  writeFileSync(
    baseFile,
    `# Copybook estate baseline (PR-020 ratchet, PR-021 inline-dupe counts).\n# Counts of the inclusion graph; update only after reviewing the\n# drift the gate prints. This baseline must only change intentionally.\nfiles=${actual.files}\nparagraphs=${actual.paragraphs}\nvars=${actual.vars}\n` +
      Object.entries(inlineDupes)
        .map(([k, v]) => `${k}=${v}\n`)
        .join(''),
  );
  console.log(`wrote ${baseFile}: ${JSON.stringify(actual)}`);
  if (details.length) {
    console.error('drift items (resolve before relying on the baseline):');
    for (const d of details) console.error(`  ${d}`);
    process.exit(1);
  }
  process.exit(0);
}

let failed = false;
const fail = (m) => {
  console.error(`FAIL: ${m}`);
  failed = true;
};
if (!want) fail(`${baseFile} missing (run with --write once, after review)`);
else {
  for (const k of Object.keys(actual)) {
    if (want[k] !== actual[k]) {
      fail(`copybook ${k}: baseline=${want[k]} actual=${actual[k]} (review drift, then --write)`);
    }
  }
}
for (const d of details) fail(d);
if (!failed)
  console.log(
    `OK: copybooks tight (${actual.files} files, ${actual.paragraphs} paragraphs, ${actual.vars} vars, 0 dead)`,
  );
process.exit(failed ? 1 : 0);
