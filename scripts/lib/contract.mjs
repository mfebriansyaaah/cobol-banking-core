// Shared contract collection (ADR-0006 follow-up): routes/*.js → per-route
// contract entries. Text parsing only (never imports gateway code), same
// balanced-brace approach as scripts/lib/route_fields.mjs, plus per-slot
// pattern/required/auth extraction for the registry.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { routeObjects, splitTopLevel, fileConstArrays } from './route_fields.mjs';

// File-local slot constants (same shape in every route file).
export const KNOWN_SLOTS = {
  BLANK: { name: '', pattern: null, required: false },
  ACTOR: { name: 'actor', pattern: 'EMAIL', required: true },
  ID: { name: 'id', pattern: 'INT', required: true },
};

export function slotDetail(entry, constArrays) {
  const t = entry.trim();
  if (!t) return { name: '', pattern: null, required: false, inline: false };
  if (t.startsWith('{')) {
    const name = (t.match(/name\s*:\s*'([^']*)'/) || [])[1] ?? '';
    const pattern = (t.match(/pattern\s*:\s*PATTERNS\.([A-Za-z0-9_]+)/) || [])[1] || null;
    const required = /required\s*:\s*true/.test(t);
    // Inline objects are client-sent fields (appear in request bodies).
    // Bare identifiers (BLANK/ACTOR/ID) are positional padding or
    // server-injected identity: never client body params.
    return { name, pattern, required, inline: true };
  }
  if (KNOWN_SLOTS[t]) return { ...KNOWN_SLOTS[t], inline: false };
  if (constArrays.get(t) !== undefined) return { shared: t };
  return { name: t, pattern: null, required: false, inline: false };
}

function findBracketEnd(body, start) {
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
  return i;
}

function expandSlot(entry, consts) {
  const d = slotDetail(entry, consts);
  if (!d.shared) return [d];
  return splitTopLevel(consts.get(d.shared))
    .filter((x) => x.trim() !== '')
    .map((sub) => slotDetail(sub, consts))
    .filter((s) => !s.shared);
}

function parseFieldsArray(body, consts, start) {
  const end = findBracketEnd(body, start);
  const parts = splitTopLevel(body.slice(body.indexOf('[', start) + 1, end));
  return parts.filter((x) => x.trim() !== '').flatMap((entry) => expandSlot(entry, consts));
}

function normalizeSlots(slots) {
  while (slots.length < 6) slots.push({ name: '', pattern: null, required: false, inline: false });
  // Slot 7 carries DEP_OPEN's idempotency key (contract v2); longer routes
  // keep their extra slots so the registry stays byte-exact with dispatch.
  return slots.map((s, i) => ({
    slot: i + 1,
    name: s.name ?? '',
    pattern: s.pattern ?? null,
    required: Boolean(s.required),
    inline: Boolean(s.inline),
    maxBytes: 100,
  }));
}

function derivedFieldsOf(body) {
  const start = body.search(/derivedFields\s*:\s*\[/);
  if (start < 0) return [];
  const end = findBracketEnd(body, start);
  return splitTopLevel(body.slice(body.indexOf('[', start) + 1, end))
    .filter((x) => x.trim() !== '')
    .map((entry) => {
      const t = entry.trim();
      const name = (t.match(/name\s*:\s*'([^']*)'/) || [])[1] ?? '';
      const pattern = (t.match(/pattern\s*:\s*PATTERNS\.([A-Za-z0-9_]+)/) || [])[1] || null;
      const required = /required\s*:\s*true/.test(t);
      return { name, pattern, required };
    });
}

function contractEntry(f, body, consts, hit, seq) {
  const m = body.match(/method\s*:\s*'([a-z]+)'/);
  const p = body.match(/path\s*:\s*'([^']+)'/);
  const a = body.match(/action\s*:\s*'([A-Z0-9_]+)'/);
  if (!m || !p || !a) return null; // custom infra routes carry no action
  const derived = derivedFieldsOf(body);
  return {
    action: a[1],
    method: m[1],
    path: p[1],
    routeFile: f,
    seq,
    module: hit.module || null,
    prefix: hit.prefix || null,
    auth: {
      public: /\bpublic\s*:\s*true\b/.test(body),
      tokenIdentity: (body.match(/tokenIdentity\s*:\s*'([^']+)'/) || [])[1] || null,
      stepUp: /\bstepUp\s*:\s*true\b/.test(body),
      stepUpPolicy: (body.match(/stepUpPolicy\s*:\s*'([^']+)'/) || [])[1] || null,
    },
    fields: fieldsOf(body, consts),
    ...(derived.length ? { derivedFields: derived } : {}),
    tested: Boolean(hit.tested),
  };
}

function fieldsOf(body, consts) {
  const start = body.search(/fields\s*:\s*\[/);
  if (start < 0) {
    const ident = (body.match(/fields\s*:\s*([A-Za-z_$][A-Za-z0-9_$]*)/) || [])[1] || null;
    const shared = ident ? consts.get(ident) : undefined;
    if (shared === undefined) return ident ? [ident] : [];
    return normalizeSlots(
      splitTopLevel(shared)
        .filter((x) => x.trim() !== '')
        .flatMap((entry) => expandSlot(entry, consts)),
    );
  }
  return normalizeSlots(parseFieldsArray(body, consts, start));
}

// All route entries with actions, sorted by (action, method, path) for human
// reading. `routeFile` + `seq` preserve manifest.gatewayRoutes file order +
// block order so downstream generators (openapi) reproduce byte-for-byte.
export function collectRouteContracts(rootDir) {
  const routesDir = path.join(rootDir, 'middleware', 'src', 'routes');
  const manifest = JSON.parse(readFileSync(path.join(rootDir, 'manifest', 'actions.json'), 'utf8'));
  const byAction = new Map();
  for (const a of manifest.actions || []) byAction.set(a.action, a);
  const modulesManifest = JSON.parse(readFileSync(path.join(rootDir, 'manifest', 'modules.json'), 'utf8'));
  const routeFiles = (modulesManifest.gatewayRoutes || []).filter((x) => x !== 'index.js');
  const out = [];
  let seq = 0;
  for (const f of routeFiles) {
    let src;
    try {
      src = readFileSync(path.join(routesDir, f), 'utf8');
    } catch {
      continue;
    }
    const consts = fileConstArrays(src);
    for (const { body } of routeObjects(src)) {
      const a = body.match(/action\s*:\s*'([A-Z0-9_]+)'/);
      if (!a) continue; // custom infra routes carry no action
      const hit = byAction.get(a[1]) || {};
      const entry = contractEntry(f, body, consts, hit, seq);
      if (!entry) continue;
      seq += 1;
      out.push(entry);
    }
  }
  out.sort((a, b) =>
    a.action < b.action
      ? -1
      : a.action > b.action
        ? 1
        : a.method < b.method
          ? -1
          : a.method > b.method
            ? 1
            : a.path < b.path
              ? -1
              : 1,
  );
  return out;
}

// Minimal reader for contracts/actions.yaml (exactly the shape our emitter
// writes: nested maps, `- ` lists, 2-space indent, JSON-quoted scalars when
// needed). Returns entries in file order. Round-trip tested: parsing the
// generated file must equal collectRouteContracts().
function parseScalar(t) {
  const s = t.trim();
  if (s === '' || s === 'null' || s === '~') return null;
  if (s === 'true') return true;
  if (s === 'false') return false;
  if (/^-?\d+$/.test(s)) return Number(s);
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    try {
      return JSON.parse(s);
    } catch {
      return s.slice(1, -1);
    }
  }
  return s;
}

function parseKeyValue(text) {
  const idx = text.indexOf(':');
  return idx > 0 ? [text.slice(0, idx), parseScalar(text.slice(idx + 1))] : null;
}

function parseSlotLine(text) {
  const rest = text.slice(2);
  const idx = rest.indexOf(':');
  if (idx > 0 && rest.slice(0, idx) === 'slot') return { slot: parseScalar(rest.slice(idx + 1)) };
  return null;
}

function startContractEntry(state, text) {
  state.cur = { action: text.slice('- action: '.length), auth: {}, fields: [] };
  state.entries.push(state.cur);
  state.field = null;
  state.dfield = null;
  state.inAuth = false;
  state.inDerived = false;
}

function parseIndent4(state, text) {
  if (text.startsWith('auth:')) {
    state.inAuth = true;
    state.inDerived = false;
    state.field = null;
    state.dfield = null;
    return;
  }
  if (text.startsWith('fields:')) {
    state.inAuth = false;
    state.inDerived = false;
    state.field = null;
    state.dfield = null;
    return;
  }
  if (text.startsWith('derivedFields:')) {
    state.inAuth = false;
    state.inDerived = true;
    state.field = null;
    state.dfield = null;
    state.cur.derivedFields = [];
    return;
  }
  if (text.startsWith('- ')) return;
  const kv = parseKeyValue(text);
  if (kv) state.cur[kv[0]] = kv[1];
  state.inAuth = false;
  state.inDerived = false;
  state.field = null;
  state.dfield = null;
}

function parseIndent6(state, text) {
  if (text.startsWith('- ')) {
    if (state.inDerived) {
      // `- name: nik`: start a derived entry (name inline after the dash).
      const kv = parseKeyValue(text.slice(2));
      state.dfield = kv ? { [kv[0]]: kv[1] } : {};
      state.cur.derivedFields.push(state.dfield);
      state.field = null;
      state.inAuth = false;
      return;
    }
    const slot = parseSlotLine(text);
    if (slot) {
      state.field = slot;
      state.cur.fields.push(slot);
    }
    state.inAuth = false;
    return;
  }
  if (!state.inAuth) return;
  const kv = parseKeyValue(text);
  if (kv) state.cur.auth[kv[0]] = kv[1];
}

function parseIndent8(state, text) {
  if (state.inDerived) {
    if (!state.dfield) return;
    const kv = parseKeyValue(text);
    if (kv) state.dfield[kv[0]] = kv[1];
    return;
  }
  if (!state.field) return;
  const kv = parseKeyValue(text);
  if (kv) state.field[kv[0]] = kv[1];
}

export function loadContract(rootDir) {
  const src = readFileSync(path.join(rootDir, 'contracts', 'actions.yaml'), 'utf8');
  const lines = src.split('\n');
  const indentOf = (ln) => ln.length - ln.trimStart().length;
  // Find the actions list and parse each `- action: X` block by indentation.
  const start = lines.findIndex((ln) => ln === 'actions:');
  if (start === -1) throw new Error('contracts/actions.yaml: no actions list');
  const state = { entries: [], cur: null, field: null, dfield: null, inAuth: false, inDerived: false };
  for (let i = start + 1; i < lines.length; i += 1) {
    const ln = lines[i];
    if (!ln.trim() || ln.trimStart().startsWith('#')) continue;
    const indent = indentOf(ln);
    const text = ln.trim();
    if (indent === 2 && text.startsWith('- action: ')) {
      startContractEntry(state, text);
      continue;
    }
    if (!state.cur) continue;
    if (indent === 4) parseIndent4(state, text);
    else if (indent === 6) parseIndent6(state, text);
    else if (indent === 8) parseIndent8(state, text);
  }
  return state.entries;
}
