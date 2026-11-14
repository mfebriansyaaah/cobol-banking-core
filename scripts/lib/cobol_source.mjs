// COPY-expansion helpers for COBOL gates (DRY-00B).
//
// Gates that reason about what a module *executes* (transaction ownership,
// field sizes of executed queries, error codes that can reach the client)
// must see through COPY includes: moving a paragraph into a copybook must
// not hide it from the gate. Gates that reason about *files* (orphans,
// dead paragraphs) keep scanning files separately.
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

const COPY_RE = /^\s*COPY\s+"([^"]+)"\s*\.\s*$/gm;

// Expand COPY "x.cpy". includes in one COBOL source, recursively.
// Missing files are left as-is (another gate reports them); cycles throw.
export function expandCopybooks(text, { copyDir, seen = [] } = {}) {
  return String(text).replace(COPY_RE, (m, file) => {
    if (seen.includes(file)) throw new Error(`COPY cycle: ${[...seen, file].join(' -> ')}`);
    const full = path.join(copyDir, file);
    if (!existsSync(full)) return m;
    const body = readFileSync(full, 'utf8');
    return expandCopybooks(body, { copyDir, seen: [...seen, file] });
  });
}

// Read a module with its COPY includes expanded.
export function loadModuleSource(root, moduleFile) {
  const full = path.join(root, 'cobol', 'src', moduleFile);
  return expandCopybooks(readFileSync(full, 'utf8'), {
    copyDir: path.join(root, 'cobol', 'copy'),
  });
}
