// Shared COBOL paragraph helpers (DRY-00A).
//
// One definition of "what counts as a top-level COBOL paragraph" so the
// gates agree. COBOL source in this repo uses 7- or 8-space area-A indent;
// verbs (END-IF, EXIT, GOBACK ...) are never paragraphs.
export const PARAGRAPH_DEF_RE = /^ {7,8}([A-Z][A-Z0-9-]+)\.\s*$/;

const VERBS = new Set([
  'END-IF',
  'END-PERFORM',
  'END-EVALUATE',
  'END-STRING',
  'END-UNSTRING',
  'END-READ',
  'END-WRITE',
  'END-CALL',
  'END-COMPUTE',
  'END-ACCEPT',
  'END-DISPLAY',
  'END-ADD',
  'END-SUBTRACT',
  'END-MULTIPLY',
  'END-DIVIDE',
  'EXIT',
  'GOBACK',
  'CONTINUE',
  'STOP',
  'ELSE',
  'WHEN',
  'THEN',
  'SPECIAL-NAMES',
  'FILE-CONTROL',
]);

export function paragraphName(line) {
  const m = String(line ?? '').match(PARAGRAPH_DEF_RE);
  if (!m) return null;
  const name = m[1];
  if (name.startsWith('END-') || VERBS.has(name)) return null;
  return name;
}

// Split source into top-level paragraphs. Returns [{ name, startLine,
// endLine, body }] with 1-based lines; endLine is exclusive (first line of
// the next paragraph or EOF). Comment lines (*>) and blank lines never start
// a paragraph and are kept inside the current body for span purposes only.
export function findParagraphs(text) {
  const lines = String(text ?? '').split('\n');
  const starts = [];
  for (let i = 0; i < lines.length; i += 1) {
    const name = paragraphName(lines[i]);
    if (name) starts.push({ index: i, name });
  }
  return starts.map((s, idx) => ({
    name: s.name,
    startLine: s.index + 1,
    endLine: idx + 1 < starts.length ? starts[idx + 1].index + 1 : lines.length + 1,
    body: lines.slice(s.index, idx + 1 < starts.length ? starts[idx + 1].index : lines.length),
  }));
}

// Count inline definitions of the given paragraph names in one source file.
export function countInlineParagraphs(text, names) {
  const wanted = new Set(names);
  const out = {};
  for (const n of wanted) out[n] = 0;
  for (const line of String(text ?? '').split('\n')) {
    const name = paragraphName(line);
    if (name && wanted.has(name)) out[name] += 1;
  }
  return out;
}
