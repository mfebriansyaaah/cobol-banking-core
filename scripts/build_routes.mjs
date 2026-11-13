// Gateway route codegen (maint-13): middleware/spec/routes.yaml is the
// single source of truth for every gateway route. This script generates
// middleware/src/routes/*.js from it (plus --check mode for CI).
// The spec language is deliberately tiny and parsed strictly below — any
// line outside the grammar fails loudly instead of silently drifting.
// Downstream artifacts (contracts/actions.yaml, docs/openapi.yaml,
// tests/contracts/route_field_order.json, the routes barrel) keep working
// unchanged: they read the generated files exactly as they read the
// hand-written ones.
// Usage: node scripts/build_routes.mjs [--write] [root]
import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const CLI_ARGS = process.argv.slice(2);
const ROOT = path.resolve(CLI_ARGS.find((a) => !a.startsWith('--')) || '.');
const WRITE = CLI_ARGS.includes('--write');

// Frozen legacy shapes: shared field constants referenced by name from the
// spec. New code must use inline fields; these exist only to reproduce the
// current tree byte-for-byte.
const KNOWN_CONSTS = {
  BLANK: `{ name: '', pattern: PATTERNS.PASSWORD, required: false }`,
  ACTOR: `{ name: 'actor', pattern: PATTERNS.EMAIL, required: true }`,
  ID: `{ name: 'id', pattern: PATTERNS.INT, required: true }`,
  TERMS: `{ name: 'terms', pattern: PATTERNS.RPT_PARAMS, required: true }`,
  INT: `{ name: 'id', pattern: PATTERNS.INT, required: true }`,
  GL: `{ name: 'glJournalId', pattern: PATTERNS.INT, required: false }`,
  DATE_FIELD: `{ name: 'date', pattern: PATTERNS.DATE, required: true }`,
  DATE_RANGE: `[\n  { name: 'from', pattern: PATTERNS.DATE, required: false },\n  { name: 'to', pattern: PATTERNS.DATE, required: false },\n  { name: 'currency', pattern: PATTERNS.CURRENCY, required: false },\n  BLANK,\n  BLANK,\n  ACTOR,\n]`,
};

function fail(msg) {
  throw new Error(`routes.yaml: ${msg}`);
}

// Split a flow list on top-level commas (quote-aware; no nesting in spec).
function splitFlow(inner) {
  const parts = [];
  let depth = 0;
  let quote = null;
  let cur = '';
  for (let i = 0; i < inner.length; i += 1) {
    const c = inner[i];
    if (quote) {
      cur += c;
      if (c === quote && inner[i - 1] !== '\\') quote = null;
      continue;
    }
    if (c === '"' || c === "'") {
      quote = c;
      cur += c;
      continue;
    }
    if (c === '[') depth += 1;
    if (c === ']') depth -= 1;
    if (c === ',' && depth === 0) {
      parts.push(cur.trim());
      cur = '';
      continue;
    }
    cur += c;
  }
  if (cur.trim()) parts.push(cur.trim());
  return parts;
}

function parseValue(raw, what) {
  const t = raw.trim();
  if (t === 'true') return true;
  if (t === 'false') return false;
  if (/^["']/.test(t)) {
    const m = t.match(/^"((?:[^"\\]|\\.)*)"$/) || t.match(/^'((?:[^'\\]|\\.)*)'$/);
    if (!m) fail(`bad string ${what}: ${t}`);
    return m[1];
  }
  // Bare words: string literals for known string keys (method/path/action),
  // identifiers everywhere else.
  if (/^[A-Za-z][A-Za-z0-9_]*$/.test(t)) return { bare: t };
  fail(`bad value ${what}: ${t}`);
  return null;
}

// Parse one `- { ... }` route line into an object. Strict: unknown keys and
// malformed fields fail loudly.
function parseRoute(line, lineno) {
  const m = line.match(/^- \{ (.*) \}$/);
  if (!m) fail(`line ${lineno}: route must be "- { ... }"`);
  const route = { extra: [] };
  for (const part of splitFlow(m[1])) {
    const kv = part.match(/^([A-Za-z][A-Za-z0-9_]*)\s*:\s*(.+)$/s);
    if (!kv) fail(`line ${lineno}: bad pair ${JSON.stringify(part)}`);
    const [, k, v] = kv;
    if (k === 'fields') {
      const t = v.trim();
      if (t.startsWith('[')) {
        route.fields = splitFlow(t.slice(1, -1)).map((f) => parseField(f, lineno));
      } else if (/^[A-Z][A-Za-z0-9_]*$/.test(t)) {
        route.fields = { ref: t };
      } else fail(`line ${lineno}: bad fields ${t}`);
    } else if (['method', 'path', 'action', 'tokenIdentity'].includes(k)) {
      const val = parseValue(v, `${k} (line ${lineno})`);
      route[k] = typeof val === 'string' ? val : val.bare;
    } else {
      const val = parseValue(v, `${k} (line ${lineno})`);
      route.extra.push([k, val && typeof val === 'object' && val.bare ? { ident: val.bare } : val]);
    }
  }
  if (!route.method || !route.path || !route.fields) {
    fail(`line ${lineno}: route needs method, path and fields`);
  }
  return route;
}

function parseField(tok, lineno) {
  const t = tok.trim();
  if (/^[A-Z][A-Z0-9_]*$/.test(t)) return { const: t };
  const m = t.match(/^([A-Za-z][A-Za-z0-9_]*)(\?)?\s*:\s*([A-Z][A-Z0-9_]*)(\?)?$/);
  if (!m) fail(`line ${lineno}: bad field ${JSON.stringify(tok)}`);
  return { name: m[1], pattern: m[3], required: !m[2] && !m[4] };
}

export function parseSpec(rootDir = ROOT) {
  const lines = readFileSync(path.join(rootDir, 'middleware', 'spec', 'routes.yaml'), 'utf8').split('\n');
  const files = [];
  let cur = null;
  lines.forEach((raw, idx) => {
    const line = raw;
    const lineno = idx + 1;
    const s = line.trim();
    if (!s || s.startsWith('#')) return;
    if (s === 'files:') return;
    let m = line.match(/^- file: (\S+)$/);
    if (m) {
      cur = { file: m[1], export: null, routes: [] };
      files.push(cur);
      return;
    }
    m = line.match(/^ {2}export: ([A-Z][A-Z0-9_]*)$/);
    if (m) {
      if (!cur) fail(`line ${lineno}: export outside a file block`);
      cur.export = m[1];
      return;
    }
    m = line.match(/^ {4}- \{/);
    if (m) {
      if (!cur || !cur.export) fail(`line ${lineno}: route outside a file/export block`);
      cur.routes.push(parseRoute(s, lineno));
      return;
    }
    fail(`line ${lineno}: unrecognized spec line ${JSON.stringify(s.slice(0, 60))}`);
  });
  return files;
}

function jsString(s) {
  return `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
}

function emitField(f) {
  if (f.const) return f.const;
  return `{ name: ${jsString(f.name)}, pattern: PATTERNS.${f.pattern}, required: ${f.required} }`;
}

const CANON_ORDER = ['method', 'path', 'action', 'tokenIdentity'];

export function emitFile(spec) {
  const usesPatterns = new Set();
  const usedConsts = [];
  const seeConst = (name) => {
    if (!KNOWN_CONSTS[name]) throw new Error(`unknown shared const ${name} (add to KNOWN_CONSTS or inline the field)`);
    if (!usedConsts.includes(name)) usedConsts.push(name);
    for (const p of KNOWN_CONSTS[name].matchAll(/PATTERNS\.([A-Z0-9_]+)/g)) usesPatterns.add(p[1]);
  };
  const routeBlocks = spec.routes.map((r) => {
    const lines = [];
    const push = (k, v, raw = false) => {
      const val = raw ? v : typeof v === 'string' ? jsString(v) : v;
      lines.push(`    ${k}: ${val},`);
    };
    for (const k of CANON_ORDER) {
      if (r[k] !== undefined) {
        push(k, r[k]);
      }
    }
    for (const [k, v] of r.extra) {
      if (v && typeof v === 'object' && v.ident) push(k, v.ident, true);
      else push(k, v);
    }
    let fieldsLine;
    if (r.fields.ref) {
      seeConst(r.fields.ref);
      fieldsLine = `    fields: ${r.fields.ref},`;
    } else if (r.fields.length === 0) {
      fieldsLine = '    fields: [],';
    } else {
      const slots = r.fields.map((f) => {
        if (f.const) {
          seeConst(f.const);
          return f.const;
        }
        usesPatterns.add(f.pattern);
        return emitField(f);
      });
      // Prettier-canonical (printWidth 120): single line when it fits,
      // expanded otherwise. Matches the hand-written tree's mix.
      const single = `    fields: [${slots.join(', ')}],`;
      fieldsLine = single.length <= 120 ? single : `    fields: [\n      ${slots.join(',\n      ')},\n    ],`;
    }
    lines.push(fieldsLine);
    return `  {\n${lines.join('\n')}\n  }`;
  });

  const head = [
    '// Generated by scripts/build_routes.mjs --write. Do not edit by hand;',
    '// edit middleware/spec/routes.yaml instead.',
  ];
  if (usesPatterns.size) head.push(`import { PATTERNS } from '../validation.js';`);
  for (const c of ['BLANK', 'ACTOR', 'ID']) {
    if (usedConsts.includes(c)) head.push(`const ${c} = ${KNOWN_CONSTS[c]};`);
  }
  for (const c of usedConsts) {
    if (!['BLANK', 'ACTOR', 'ID'].includes(c)) head.push(`const ${c} = ${KNOWN_CONSTS[c]};`);
  }
  head.push(`export const ${spec.export} = [`);
  return `${head.join('\n')}\n${routeBlocks.join(',\n')},\n];\n`;
}

export function buildAll(rootDir = ROOT) {
  const out = new Map();
  for (const spec of parseSpec(rootDir)) {
    out.set(`middleware/src/routes/${spec.file}`, emitFile(spec));
  }
  return out;
}

const isMain = import.meta.url === pathToFileURL(process.argv[1] ?? '').href;
if (isMain) {
  const built = buildAll(ROOT);
  if (!WRITE) {
    const failures = [];
    for (const [rel, text] of built) {
      const p = path.join(ROOT, rel);
      if (!existsSync(p)) failures.push(`${rel}: missing (run with --write)`);
      else if (readFileSync(p, 'utf8') !== text) failures.push(`${rel}: differs from spec (run with --write)`);
    }
    // No orphan route files beyond the barrel: every generated file must be
    // in the spec, and the on-disk set must match exactly.
    const onDisk = new Set(
      readdirSync(path.join(ROOT, 'middleware', 'src', 'routes')).filter((f) => f.endsWith('.js') && f !== 'index.js'),
    );
    for (const name of [...built.keys()].map((k) => path.basename(k))) onDisk.delete(name);
    for (const rest of onDisk)
      failures.push(`middleware/src/routes/${rest}: not generated from the spec (remove or add to it)`);
    if (failures.length) {
      console.error('FAIL: route files do not match middleware/spec/routes.yaml:');
      for (const f of failures) console.error(`  ${f}`);
      process.exit(1);
    }
    console.log(`OK: ${built.size} route files match the spec`);
  } else {
    for (const [rel, text] of built) {
      const p = path.join(ROOT, rel);
      mkdirSync(path.dirname(p), { recursive: true });
      writeFileSync(p, text);
    }
    console.log(`Wrote ${built.size} route files from the spec`);
  }
}
