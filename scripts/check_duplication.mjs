// Duplication audit gate (DRY-00A): the COBOL tree must not gain new
// duplication. Metrics live in tests/duplication_baseline.txt; the gate
// fails on drift with exact numbers. Run with --write after review to
// refresh the baseline.
//
// Metrics:
//   paragraph_groups / paragraph_redundant_lines: identical (name, body)
//     paragraph groups across files (min 5 code lines); redundant lines
//     exclude one canonical copy.
//   ws_blocks / ws_redundant_lines: identical WORKING-STORAGE blocks
//     (>= 20 decl lines) across files.
//   inline_*: inline definitions of shared paragraphs in cobol/src.
//   unused_ws_decls: inline 01 declarations never referenced in the host
//     file expanded with its COPY includes; an 01 owning a referenced
//     88-level counts as used.
//
// Usage: node scripts/check_duplication.mjs [--check|--write|--json|--markdown] [ROOT]
import { createHash } from 'node:crypto';
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { findParagraphs, countInlineParagraphs } from './lib/cobol_paragraphs.mjs';

const args = process.argv.slice(2);
let root = '.';
let mode = 'check';
for (let i = 0; i < args.length; i += 1) {
  const a = args[i];
  if (a === '--write') mode = 'write';
  else if (a === '--check') mode = 'check';
  else if (a === '--json') mode = 'json';
  else if (a === '--markdown') mode = 'markdown';
  else if (a === '--help' || a === '-h') {
    console.log('usage: check_duplication.mjs [--check|--write|--json|--markdown] [ROOT]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else root = a;
}
root = path.resolve(root);

const srcDir = path.join(root, 'cobol', 'src');
const copyDir = path.join(root, 'cobol', 'copy');
const baseFile = path.join(root, 'tests', 'duplication_baseline.txt');

const INLINE_NAMES = ['TRIM-ALL', 'TRIM-VALUE', 'TRIM-RESULT-LEN', 'VALIDATE-ALL', 'VALIDATE-INPUT', 'TRIM-ONE'];

// Normalize one code line for hashing: drop comments/blanks, collapse space.
function normLine(line) {
  const t = String(line ?? '')
    .split('*>')[0]
    .replace(/\s+/g, ' ')
    .trim();
  return t === '' ? null : t;
}

function normBody(lines) {
  return lines.map(normLine).filter((l) => l !== null);
}

function sha(text) {
  return createHash('sha1').update(text, 'utf8').digest('hex');
}

function listFiles(dir, ext) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((f) => f.endsWith(ext))
    .sort();
}

const cobolFiles = listFiles(srcDir, '.cob');
const cpyFiles = listFiles(copyDir, '.cpy');
const srcOf = new Map(cobolFiles.map((f) => [f, readFileSync(path.join(srcDir, f), 'utf8')]));
const copyOf = new Map(cpyFiles.map((f) => [f, readFileSync(path.join(copyDir, f), 'utf8')]));

function expandCopybooks(text) {
  return String(text).replace(/^\s*COPY\s+"([^"]+)"\s*\.\s*$/gm, (m, file) => copyOf.get(file) ?? m);
}

// ---- 1. Identical paragraph groups across files (min 5 code lines) ----
const groupMembers = new Map(); // key -> [{file, lines}]
for (const [file, text] of srcOf) {
  for (const p of findParagraphs(text)) {
    const body = normBody(p.body.slice(1)); // exclude the definition line
    if (body.length < 5) continue;
    const key = `${p.name}\n${sha(body.join('\n'))}`;
    if (!groupMembers.has(key)) groupMembers.set(key, []);
    groupMembers.get(key).push({ file, lines: body.length });
  }
}
let paragraphGroups = 0;
let paragraphRedundant = 0;
const groupDetails = [];
for (const [key, members] of groupMembers) {
  const files = new Set(members.map((m) => m.file));
  if (files.size < 2) continue;
  paragraphGroups += 1;
  const lines = members[0].lines;
  paragraphRedundant += (members.length - 1) * lines;
  const name = key.split('\n')[0];
  groupDetails.push({ name, lines, instances: members.length, redundant: (members.length - 1) * lines });
}
groupDetails.sort((a, b) => b.redundant - a.redundant);

// ---- 2. Identical WORKING-STORAGE blocks (>= 20 decl lines) ----
function wsBlock(text) {
  const m = String(text).match(/^.*WORKING-STORAGE SECTION\.\s*$/m);
  if (!m) return [];
  const rest = String(text).slice(m.index + m[0].length);
  const end = rest.search(/^.*(?:LINKAGE SECTION|PROCEDURE DIVISION)\./m);
  const body = end >= 0 ? rest.slice(0, end) : rest;
  return normBody(body.split('\n'));
}
const wsGroups = new Map();
for (const [file, text] of srcOf) {
  const block = wsBlock(text);
  if (block.length < 20) continue;
  const key = sha(block.join('\n'));
  if (!wsGroups.has(key)) wsGroups.set(key, []);
  wsGroups.get(key).push({ file, lines: block.length });
}
let wsBlocks = 0;
let wsRedundant = 0;
for (const members of wsGroups.values()) {
  if (members.length < 2) continue;
  wsBlocks += 1;
  wsRedundant += (members.length - 1) * members[0].lines;
}

// ---- 3. Inline counts in cobol/src ----
const inlineCounts = {};
for (const name of INLINE_NAMES) inlineCounts[name] = 0;
for (const text of srcOf.values()) {
  const counts = countInlineParagraphs(text, INLINE_NAMES);
  for (const name of INLINE_NAMES) inlineCounts[name] += counts[name] ?? 0;
}

// ---- 4. Unused inline 01 declarations (COPY-expanded, 88-aware) ----
let unusedWsDecls = 0;
const unusedByFile = new Map();
for (const [file, text] of srcOf) {
  const expanded = expandCopybooks(text);
  const declLines = new Set();
  const decls = []; // {name, lineIdx, children88: []}
  const rawLines = String(text).split('\n');
  let cur = null;
  rawLines.forEach((line, idx) => {
    let m = line.match(/^\s+01\s+([A-Z][A-Z0-9-]+)\s+PIC/i);
    if (m) {
      cur = { name: m[1], lineIdx: idx, children88: [] };
      decls.push(cur);
      declLines.add(idx);
      return;
    }
    m = line.match(/^\s+88\s+([A-Z][A-Z0-9-]+)\s/);
    if (m && cur) cur.children88.push(m[1]);
  });
  const codeText = expanded;
  const unused = [];
  for (const d of decls) {
    const refs = [...codeText.matchAll(new RegExp(`\\b${d.name}\\b`, 'g'))].filter((m) => {
      const lineNo = codeText.slice(0, m.index).split('\n').length - 1;
      // Skip the declaration line itself (host 01 line).
      const expandedLines = expanded.split('\n');
      const line = expandedLines[lineNo] ?? '';
      return !new RegExp(`^\\s+01\\s+${d.name}\\s`, 'i').test(line);
    });
    if (refs.length > 0) continue;
    // An 01 owning a referenced 88-level is used via its children.
    // STEP-OK/STEP-FAIL style flags are the common case.
    const childUsed = d.children88.some((c) => new RegExp(`\\b${c}\\b`).test(codeText));
    if (childUsed) continue;
    unused.push(d.name);
  }
  if (unused.length) unusedByFile.set(file, unused);
  unusedWsDecls += unused.length;
}

const actual = {
  paragraph_groups: paragraphGroups,
  paragraph_redundant_lines: paragraphRedundant,
  ws_blocks: wsBlocks,
  ws_redundant_lines: wsRedundant,
  inline_trim_all: inlineCounts['TRIM-ALL'],
  inline_trim_value: inlineCounts['TRIM-VALUE'],
  inline_trim_result_len: inlineCounts['TRIM-RESULT-LEN'],
  inline_validate_all: inlineCounts['VALIDATE-ALL'],
  inline_validate_input: inlineCounts['VALIDATE-INPUT'],
  inline_trim_one: inlineCounts['TRIM-ONE'],
  unused_ws_decls: unusedWsDecls,
};

function loadBaseline() {
  if (!existsSync(baseFile)) return null;
  const want = {};
  for (const line of readFileSync(baseFile, 'utf8').split('\n')) {
    const m = line.match(/^(\w+)=(\d+)$/);
    if (m) want[m[1]] = Number(m[2]);
  }
  return want;
}

function baselineText() {
  const header =
    '# Duplication baseline (DRY-00A ratchet). Counts from scripts/check_duplication.mjs.\n' +
    '# Update only after reviewing the drift the gate prints (--write). This baseline must only shrink.\n';
  return (
    header +
    Object.entries(actual)
      .map(([k, v]) => `${k}=${v}\n`)
      .join('')
  );
}

function report() {
  const lines = [
    `paragraph groups: ${actual.paragraph_groups} (${actual.paragraph_redundant_lines} redundant lines)`,
    `working-storage blocks: ${actual.ws_blocks} (${actual.ws_redundant_lines} redundant lines)`,
    `inline: TRIM-ALL=${actual.inline_trim_all} TRIM-VALUE=${actual.inline_trim_value} TRIM-RESULT=${actual.inline_trim_result_len} VALIDATE-ALL=${actual.inline_validate_all} VALIDATE-INPUT=${actual.inline_validate_input} TRIM-ONE=${actual.inline_trim_one}`,
    `unused 01 declarations: ${actual.unused_ws_decls}`,
  ];
  return lines.join('\n');
}

if (mode === 'json') {
  console.log(
    JSON.stringify(
      {
        ...actual,
        top_groups: groupDetails.slice(0, 10),
        top_unused: [...unusedByFile.entries()]
          .map(([file, names]) => ({ file, count: names.length, names: names.slice(0, 8) }))
          .sort((a, b) => b.count - a.count)
          .slice(0, 10),
      },
      null,
      2,
    ),
  );
  process.exit(0);
}

if (mode === 'markdown') {
  console.log('| Metric | Value |');
  console.log('| --- | ---: |');
  for (const [k, v] of Object.entries(actual)) console.log(`| ${k} | ${v} |`);
  console.log('');
  console.log('| Paragraph | Lines | Instances | Redundant |');
  console.log('| --- | ---: | ---: | ---: |');
  for (const g of groupDetails.slice(0, 10))
    console.log(`| ${g.name} | ${g.lines} | ${g.instances} | ${g.redundant} |`);
  process.exit(0);
}

if (mode === 'write') {
  writeFileSync(baseFile, baselineText());
  console.log(`wrote ${baseFile}: ${JSON.stringify(actual)}`);
  process.exit(0);
}

// check (default)
const want = loadBaseline();
let failed = false;
if (!want) {
  console.error(`FAIL: ${baseFile} missing (run with --write once, after review)`);
  process.exit(2);
}
for (const k of Object.keys(actual)) {
  if (want[k] === undefined) {
    console.error(`FAIL: duplication ${k}: baseline missing actual=${actual[k]} (review drift, then --write)`);
    failed = true;
  } else if (want[k] !== actual[k]) {
    console.error(`FAIL: duplication ${k}: baseline=${want[k]} actual=${actual[k]} (review drift, then --write)`);
    failed = true;
  }
}
for (const k of Object.keys(want)) {
  if (actual[k] === undefined) {
    console.error(`FAIL: duplication ${k}: baseline=${want[k]} actual=missing (review drift, then --write)`);
    failed = true;
  }
}
if (!failed) console.log(`OK: duplication holds\n${report()}`);
else console.error(report());
process.exit(failed ? 1 : 0);
