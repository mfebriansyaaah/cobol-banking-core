// Unit tests for scripts/lib/cobol_paragraphs.mjs. No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { paragraphName, findParagraphs, countInlineParagraphs } from '../lib/cobol_paragraphs.mjs';

test('7-space paragraph detected', () => {
  assert.equal(paragraphName('       TRIM-ALL.'), 'TRIM-ALL');
});

test('8-space paragraph detected', () => {
  assert.equal(paragraphName('        TRIM-ALL.'), 'TRIM-ALL');
});

test('END-IF is not a paragraph', () => {
  assert.equal(paragraphName('            END-IF.'), null);
  assert.equal(paragraphName('       END-PERFORM.'), null);
});

test('EXIT/GOBACK are not paragraphs', () => {
  assert.equal(paragraphName('            EXIT PARAGRAPH.'), null);
  assert.equal(paragraphName('            GOBACK.'), null);
});

test('comments and blanks do not start paragraphs', () => {
  assert.equal(paragraphName('      *> a comment.'), null);
  assert.equal(paragraphName(''), null);
  assert.equal(paragraphName('        MOVE X TO Y.'), null);
});

test('findParagraphs spans are 1-based and exclusive', () => {
  const src = ['        TRIM-ALL.', '            MOVE A TO B.', '        TRIM-VALUE.', '            MOVE C TO D.'].join(
    '\n',
  );
  const paras = findParagraphs(src);
  assert.equal(paras.length, 2);
  assert.deepEqual([paras[0].name, paras[0].startLine, paras[0].endLine], ['TRIM-ALL', 1, 3]);
  assert.deepEqual([paras[1].name, paras[1].startLine, paras[1].endLine], ['TRIM-VALUE', 3, 5]);
});

test('countInlineParagraphs counts only wanted names', () => {
  const src = ['        TRIM-ALL.', '        TRIM-ALL.', '        TRIM-VALUE.'].join('\n');
  assert.deepEqual(countInlineParagraphs(src, ['TRIM-ALL', 'TRIM-VALUE']), { 'TRIM-ALL': 2, 'TRIM-VALUE': 1 });
});
