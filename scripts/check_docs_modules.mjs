// Living-docs module-reference gate (Phase 1).
//
// Generated inventories cannot drift, but hand-written docs can name modules
// that were retired or never existed. This gate scans living documentation
// (README + docs, excluding historical archive/ and adr/) for backticked
// `*_core` names and requires a matching cobol/src/<name>.cob.
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

// Historical records may name retired modules on purpose; the active
// inventory must not.
const HISTORICAL_DIRS = new Set(['archive', 'adr']);

function walkMarkdown(dir) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const entry of readdirSync(dir)) {
    const full = path.join(dir, entry);
    if (statSync(full).isDirectory()) {
      if (HISTORICAL_DIRS.has(entry)) continue;
      out.push(...walkMarkdown(full));
    } else if (entry.endsWith('.md')) {
      out.push(full);
    }
  }
  return out;
}

export function livingDocs(rootDir = ROOT) {
  const files = [
    path.join(rootDir, 'README.md'),
    path.join(rootDir, 'CONTRIBUTING.md'),
    path.join(rootDir, 'SECURITY.md'),
    ...walkMarkdown(path.join(rootDir, 'docs')),
  ];
  return files.filter((f) => existsSync(f));
}

export function missingModules(rootDir = ROOT) {
  const missing = [];
  for (const file of livingDocs(rootDir)) {
    const text = readFileSync(file, 'utf8');
    for (const match of text.matchAll(/`([a-z][a-z0-9_]*_core)`/g)) {
      const module = match[1];
      if (!existsSync(path.join(rootDir, 'cobol', 'src', `${module}.cob`))) {
        const line = text.slice(0, match.index).split('\n').length;
        missing.push({ file: path.relative(rootDir, file), line, module });
      }
    }
  }
  return missing;
}

function main(argv) {
  const rootDir = path.resolve(argv[0] || ROOT);
  const missing = missingModules(rootDir);
  if (missing.length > 0) {
    for (const m of missing)
      console.error(`FAIL: ${m.file}:${m.line}: module \`${m.module}\` has no cobol/src/${m.module}.cob`);
    return 1;
  }
  console.log(`OK: living docs reference only existing modules (${livingDocs(rootDir).length} file(s))`);
  return 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
