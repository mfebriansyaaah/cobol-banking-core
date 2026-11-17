// Unit tests for scripts/docs_toc.mjs (docs hygiene). No database, no build.
// Pure render/slug helpers are imported directly; CLI + freshness checks run
// against a temp mini docs tree.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { renderDocWithToc, tocStaleFiles } from '../docs_toc.mjs';
import { runGate } from './helpers.mjs';

const EM_DASH = String.fromCharCode(0x2014);

test('renderDocWithToc returns null when the file did not opt in', () => {
  assert.equal(renderDocWithToc('# Title\n\n## Section\n'), null);
});

test('renderDocWithToc inserts a canonical ToC and is idempotent', () => {
  const input = [
    '# Title',
    '',
    'intro',
    '',
    '<!-- BEGIN GENERATED TOC -->',
    '<!-- END GENERATED TOC -->',
    '',
    '## Alpha',
    '',
    '### Beta one',
    '',
  ].join('\n');
  const expected = [
    '# Title',
    '',
    'intro',
    '',
    '<!-- BEGIN GENERATED TOC -->',
    '',
    '- [Alpha](#alpha)',
    '  - [Beta one](#beta-one)',
    '',
    '<!-- END GENERATED TOC -->',
    '',
    '## Alpha',
    '',
    '### Beta one',
    '',
  ].join('\n');
  const once = renderDocWithToc(input);
  assert.equal(once, expected);
  assert.equal(renderDocWithToc(once), once);
});

test('anchors follow GitHub rules: underscores kept, punctuation stripped, spaces not collapsed', () => {
  const input = [
    '<!-- BEGIN GENERATED TOC -->',
    '<!-- END GENERATED TOC -->',
    '',
    '## Rate_store v2: a + b',
    '',
    `## Cut ${EM_DASH} here`,
    '',
  ].join('\n');
  const out = renderDocWithToc(input);
  assert.match(out, /\(#rate_store-v2-a--b\)/);
  assert.match(out, /\(#cut--here\)/);
});

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeDocsTree() {
  const root = mkdtempSync(path.join(tmpdir(), 'toc-fixture-'));
  dirs.push(root);
  mkdirSync(path.join(root, 'docs', 'archive'), { recursive: true });
  writeFileSync(
    path.join(root, 'docs', 'guide.md'),
    ['# Guide', '', '<!-- BEGIN GENERATED TOC -->', '<!-- END GENERATED TOC -->', '', '## Setup', ''].join('\n'),
  );
  writeFileSync(path.join(root, 'docs', 'plain.md'), '# Plain\n\nNo markers here.\n');
  writeFileSync(
    path.join(root, 'docs', 'archive', 'old.md'),
    ['# Old', '', '<!-- BEGIN GENERATED TOC -->', '<!-- END GENERATED TOC -->', '', '## Dusty', ''].join('\n'),
  );
  return root;
}

test('tocStaleFiles flags opted-in docs and skips archive', () => {
  const root = makeDocsTree();
  assert.deepEqual(tocStaleFiles(root), ['docs/guide.md']);
});

test('docs_toc.mjs --check passes after --write', () => {
  const root = makeDocsTree();
  const wrote = runGate('scripts/docs_toc.mjs', ['--write', root]);
  assert.equal(wrote.status, 0, `docs_toc --write failed: ${wrote.stderr}`);
  assert.deepEqual(tocStaleFiles(root), []);
  const checked = runGate('scripts/docs_toc.mjs', ['--check', root]);
  assert.equal(checked.status, 0, `docs_toc --check failed: ${checked.stderr}`);
});
