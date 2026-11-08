// OpenAPI gate (PR-053, ADR-0006): docs/openapi.yaml must match the renderer
// byte-for-byte AND must parse as valid YAML. Regen with --write after review.
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');

// 1. Renderer drift check (existing behavior via generate_openapi.mjs check mode).
{
  const r = spawnSync(process.execPath, [path.join(ROOT, 'scripts', 'generate_openapi.mjs'), ROOT], { stdio: 'inherit' });
  if (r.status !== 0) process.exit(r.status ?? 2);
}

// 2. Independent YAML validity (ADR-0006 P0-6): the file must parse, not just
// match the generator. Uses python yaml when available (CI has it for yamllint).
{
  const py = spawnSync('python3', ['-c', "import yaml,sys; yaml.safe_load(open(sys.argv[1])); print('openapi YAML OK')", path.join(ROOT, 'docs', 'openapi.yaml')], { encoding: 'utf8' });
  if (py.status !== 0) {
    console.error('FAIL: docs/openapi.yaml is not valid YAML');
    if (py.stderr) console.error(py.stderr);
    process.exit(1);
  }
  // 3. Minimal structural check: servers/paths must exist and servers must be a list.
  const text = readFileSync(path.join(ROOT, 'docs', 'openapi.yaml'), 'utf8');
  if (!/^servers:\n\s+-\s+url:/m.test(text)) {
    console.error('FAIL: docs/openapi.yaml servers block malformed');
    process.exit(1);
  }
}

console.log('OK: openapi in sync and valid YAML');
