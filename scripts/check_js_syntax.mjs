// Fast JS syntax gate: parses every gateway/script source in ONE node process
// instead of spawning one `node --check` per file (~31s -> <1s).
//
// `vm.SourceTextModule` only parses (no linking), which is exactly what a
// syntax gate needs. Module-goal parsing is stricter than script goal (e.g.
// `with`), so a file that fails to parse is re-checked with the real
// `node --check` before being reported: only what node itself rejects fails.
//
// Usage: node --experimental-vm-modules scripts/check_js_syntax.mjs [root]
import { readdirSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import vm from 'node:vm';

const ROOT = path.resolve(process.argv[2] || '.');
const DIRS = ['middleware/src', 'scripts'].map((d) => path.join(ROOT, d));

function collect(dir, out) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) collect(p, out);
    else if (/\.(js|mjs)$/.test(e.name)) out.push(p);
  }
}

const files = [];
for (const d of DIRS) collect(d, files);
files.sort();

const canParse = typeof vm.SourceTextModule === 'function';
let bad = 0;
for (const f of files) {
  const src = readFileSync(f, 'utf8');
  let failed = false;
  if (canParse) {
    try {
      new vm.SourceTextModule(src, { identifier: f });
    } catch {
      failed = true;
    }
  } else {
    failed = true; // ancient node: fall through to `node --check`
  }
  if (failed) {
    try {
      execFileSync(process.execPath, ['--check', f], { stdio: 'pipe' });
      failed = false; // node accepts it: module-goal false positive
    } catch (e) {
      const msg = String((e && e.stderr) || (e && e.message) || e)
        .split('\n')
        .slice(0, 3)
        .map((l) => `    ${l}`)
        .join('\n');
      bad += 1;
      console.error(`FAIL: ${path.relative(ROOT, f)}`);
      console.error(msg);
    }
  }
}

if (bad > 0) {
  console.error(`FAIL: ${bad} file(s) cannot be parsed`);
  process.exit(1);
}
console.log(`OK: ${files.length} JS sources parse`);
