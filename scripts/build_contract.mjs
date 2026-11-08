// Contract registry builder (ADR-0006 follow-up, phase 1).
// Single source of truth for the gateway↔COBOL contract: every gateway
// action with its method/path, 6 positional slots (name/pattern/required),
// auth shape, dispatch module/prefix, and shell-test evidence.
// Generated, never hand-edited:
//   node scripts/build_contract.mjs --write   (review the diff)
// The gate (scripts/check_contract.mjs) fails on drift.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { collectRouteContracts } from './lib/contract.mjs';

const args = process.argv.slice(2);
const WRITE = args.includes('--write');
const ROOT = path.resolve(args.find((a) => !a.startsWith('--')) || '.');
const OUT_PATH = path.join(ROOT, 'contracts', 'actions.yaml');

function yamlScalar(v) {
  if (v === null || v === undefined) return 'null';
  if (typeof v === 'boolean' || typeof v === 'number') return String(v);
  const s = String(v);
  if (
    s === '' ||
    /[:#[\]{},&*!|>'"%@`\n]/.test(s) ||
    /^\s|\s$/.test(s) ||
    /^(true|false|null|~|[0-9]+(\.[0-9]+)?)$/.test(s)
  ) {
    return JSON.stringify(s);
  }
  return s;
}

function toYaml(value, indent = 0) {
  const pad = '  '.repeat(indent);
  if (Array.isArray(value)) {
    if (!value.length) return '[]';
    const lines = [];
    for (const v of value) {
      if (v && typeof v === 'object') {
        const keys = Object.keys(v);
        if (!keys.length) {
          lines.push(`${pad}- {}`);
          continue;
        }
        const [first, ...rest] = keys;
        lines.push(`${pad}- ${yamlScalar(first)}:${toYaml(v[first], indent + 1).replace(/^(?!\n)/, ' ')}`);
        for (const k of rest) {
          lines.push(`${pad}  ${yamlScalar(k)}:${toYaml(v[k], indent + 2).replace(/^(?!\n)/, ' ')}`);
        }
      } else {
        lines.push(`${pad}- ${yamlScalar(v)}`);
      }
    }
    return `\n${lines.join('\n')}`;
  }
  if (value && typeof value === 'object') {
    const keys = Object.keys(value);
    if (!keys.length) return '{}';
    return `\n${keys.map((k) => `${pad}${yamlScalar(k)}:${toYaml(value[k], indent + 1).replace(/^(?!\n)/, ' ')}`).join('\n')}`;
  }
  return yamlScalar(value);
}

const actions = collectRouteContracts(ROOT);

const doc = {
  version: 1,
  generatedAt: new Date().toISOString(),
  generator: 'scripts/build_contract.mjs (do not hand-edit)',
  count: actions.length,
  actions,
};

const rendered = `# Contract registry (ADR-0006 follow-up): single source of truth for the
# gateway↔COBOL contract. Generated from routes/*.js + manifest/actions.json;
# never hand-edit. Validate with scripts/check_contract.mjs, regenerate with
# --write after a reviewed route change.
${Object.keys(doc)
  .map((k) => `${k}:${toYaml(doc[k], 1).replace(/^(?!\n)/, ' ')}`)
  .join('\n')}\n`;

if (!WRITE) {
  if (!existsSync(OUT_PATH)) {
    console.error(`FAIL: missing ${path.relative(ROOT, OUT_PATH)}; run with --write`);
    process.exit(1);
  }
  const current = readFileSync(OUT_PATH, 'utf8');
  // generatedAt churns on every run: compare the semantic payload only.
  const strip = (s) => s.replace(/^generatedAt:.*$/m, 'generatedAt: STRIPPED');
  if (strip(current) !== strip(rendered)) {
    console.error('contract drifted: run scripts/build_contract.mjs --write and review the diff');
    process.exit(1);
  }
  console.log(`OK: contract in sync (${actions.length} actions)`);
} else {
  mkdirSync(path.dirname(OUT_PATH), { recursive: true });
  writeFileSync(OUT_PATH, rendered);
  console.log(`wrote ${path.relative(ROOT, OUT_PATH)}: ${actions.length} actions`);
}
