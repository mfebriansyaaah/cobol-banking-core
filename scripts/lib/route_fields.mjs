// Shared route-table parser for the field-order contract (P0-4).
// Parses route objects as TEXT (never imports gateway code): each route is a
// balanced `{...}` whose first key is `method`. For every route returns
// { method, path, action, fields } where fields is the 6 slot tokens in
// source order: inline `{ name: 'x', ... }` entries yield their name string,
// shared constants (BLANK, ACTOR, ID, ...) yield the identifier.
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

// Balanced-brace scan that ignores braces inside string literals.
export function routeObjects(source) {
  const found = [];
  for (let i = 0; i < source.length; i += 1) {
    if (source[i] !== '{') continue;
    if (!/^\s*method\s*:/.test(source.slice(i + 1, i + 40))) continue;
    let depth = 0;
    let quote = null;
    let j = i;
    for (; j < source.length; j += 1) {
      const ch = source[j];
      if (quote) {
        if (ch === quote && source[j - 1] !== '\\') quote = null;
        continue;
      }
      if (ch === "'" || ch === '"') {
        quote = ch;
        continue;
      }
      if (ch === '{') depth += 1;
      else if (ch === '}') {
        depth -= 1;
        if (depth === 0) break;
      }
    }
    found.push({ body: source.slice(i, j + 1), line: source.slice(0, i).split('\n').length });
    i = j;
  }
  return found;
}

// Split a bracketed list on top-level commas (nesting-, paren- and
// quote-aware).
export function splitTopLevel(inner) {
  const parts = [];
  let depthBrace = 0;
  let depthBracket = 0;
  let depthParen = 0;
  let quote = null;
  let cur = '';
  for (let i = 0; i < inner.length; i += 1) {
    const ch = inner[i];
    if (quote) {
      cur += ch;
      if (ch === quote && inner[i - 1] !== '\\') quote = null;
      continue;
    }
    if (ch === "'" || ch === '"') {
      quote = ch;
      cur += ch;
      continue;
    }
    if (ch === '{') depthBrace += 1;
    else if (ch === '}') depthBrace -= 1;
    else if (ch === '[') depthBracket += 1;
    else if (ch === ']') depthBracket -= 1;
    else if (ch === '(') depthParen += 1;
    else if (ch === ')') depthParen -= 1;
    if (ch === ',' && depthBrace === 0 && depthBracket === 0 && depthParen === 0) {
      parts.push(cur);
      cur = '';
      continue;
    }
    cur += ch;
  }
  parts.push(cur);
  return parts;
}

function bracketInner(body, key) {
  const start = body.search(new RegExp(`${key}\\s*:\\s*\\[`));
  if (start < 0) return null;
  let i = body.indexOf('[', start);
  let depth = 0;
  let quote = null;
  for (; i < body.length; i += 1) {
    const ch = body[i];
    if (quote) {
      if (ch === quote && body[i - 1] !== '\\') quote = null;
      continue;
    }
    if (ch === "'" || ch === '"') {
      quote = ch;
      continue;
    }
    if (ch === '[') depth += 1;
    else if (ch === ']') {
      depth -= 1;
      if (depth === 0) break;
    }
  }
  return body.slice(body.indexOf('[', start) + 1, i);
}

// Top-level `const NAME = [...]` array definitions in one file, for routes
// whose `fields` is a shared identifier (e.g. `fields: DATE_RANGE`).
// Expanding the constant keeps drift inside the constant visible.
export function fileConstArrays(source) {
  const out = new Map();
  const re = /const\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*\[/g;
  let m;
  while ((m = re.exec(source)) !== null) {
    let depth = 0;
    let quote = null;
    let j = m.index + m[0].length - 1;
    for (; j < source.length; j += 1) {
      const ch = source[j];
      if (quote) {
        if (ch === quote && source[j - 1] !== '\\') quote = null;
        continue;
      }
      if (ch === "'" || ch === '"') {
        quote = ch;
        continue;
      }
      if (ch === '[') depth += 1;
      else if (ch === ']') {
        depth -= 1;
        if (depth === 0) break;
      }
    }
    out.set(m[1], source.slice(m.index + m[0].length, j));
  }
  return out;
}
// One slot token: inline object -> its name string (or '' when nameless);
// bare identifier (BLANK, ACTOR, ID, ...) -> the identifier itself.
export function slotToken(entry) {
  const t = entry.trim();
  if (!t) return '';
  if (t.startsWith('{')) {
    const m = t.match(/name\s*:\s*'([^']*)'/);
    return m ? m[1] : '';
  }
  const m = t.match(/^([A-Za-z_$][A-Za-z0-9_$]*)/);
  return m ? m[1] : t;
}

export function parseRoute(body, constArrays = new Map()) {
  const method = (body.match(/method\s*:\s*'([a-z]+)'/) || [])[1] || null;
  const routePath = (body.match(/path\s*:\s*'([^']+)'/) || [])[1] || null;
  const action = (body.match(/action\s*:\s*'([A-Z0-9_]+)'/) || [])[1] || null;
  const tokenIdentity = (body.match(/tokenIdentity\s*:\s*'([^']+)'/) || [])[1] || null;
  const stepUp = /\bstepUp\s*:\s*true\b/.test(body);
  const inner = bracketInner(body, 'fields');
  // A trailing comma before `]` yields one empty part; no valid route has an
  // empty slot (BLANK is the explicit empty marker), so drop empties.
  let fields;
  if (inner !== null) {
    fields = splitTopLevel(inner).filter((p) => p.trim() !== '').map(slotToken);
  } else {
    // Shared constant: `fields: DATE_RANGE`. Expand the file-local definition
    // so drift inside the constant is visible; fall back to the identifier.
    const ident = (body.match(/fields\s*:\s*([A-Za-z_$][A-Za-z0-9_$]*)/) || [])[1] || null;
    const shared = ident ? constArrays.get(ident) : undefined;
    fields = shared === undefined ? (ident ? [ident] : null)
      : splitTopLevel(shared).filter((p) => p.trim() !== '').map(slotToken);
  }
  return { method, path: routePath, action, tokenIdentity, stepUp, fields };
}

// All routes keyed by `file :: METHOD path`. Same-file exact duplicates
// (tracked separately by check_route_conflicts) collapse to an array.
export function collectRoutes(rootDir) {
  const routesDir = path.join(rootDir, 'middleware', 'src', 'routes');
  const out = new Map();
  const add = (file, body, consts = new Map()) => {
    const r = parseRoute(body, consts);
    if (!r.method || !r.path) return;
    const key = `${file} :: ${r.method.toUpperCase()} ${r.path}`;
    const entry = { action: r.action, fields: r.fields, tokenIdentity: r.tokenIdentity, stepUp: r.stepUp };
    if (out.has(key)) {
      const cur = out.get(key);
      out.set(key, Array.isArray(cur) ? [...cur, entry] : [cur, entry]);
    } else {
      out.set(key, entry);
    }
  };
  for (const f of readdirSync(routesDir).filter((x) => x.endsWith('.js') && x !== 'index.js').sort()) {
    const src = readFileSync(path.join(routesDir, f), 'utf8');
    const consts = fileConstArrays(src);
    for (const { body } of routeObjects(src)) add(f, body, consts);
  }
  const appSrc = readFileSync(path.join(rootDir, 'middleware', 'src', 'app.js'), 'utf8');
  const appConsts = fileConstArrays(appSrc);
  for (const { body } of routeObjects(appSrc)) add('app.js', body, appConsts);
  return out;
}
