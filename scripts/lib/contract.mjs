// Shared contract collection (ADR-0006 follow-up): routes/*.js → per-route
// contract entries. Text parsing only (never imports gateway code), same
// balanced-brace approach as scripts/lib/route_fields.mjs, plus per-slot
// pattern/required/auth extraction for the registry.
import { readdirSync, readFileSync } from 'node:fs';
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
  if (!t) return { name: '', pattern: null, required: false };
  if (t.startsWith('{')) {
    const name = (t.match(/name\s*:\s*'([^']*)'/) || [])[1] ?? '';
    const pattern = (t.match(/pattern\s*:\s*PATTERNS\.([A-Za-z0-9_]+)/) || [])[1] || null;
    const required = /required\s*:\s*true/.test(t);
    return { name, pattern, required };
  }
  if (KNOWN_SLOTS[t]) return { ...KNOWN_SLOTS[t] };
  if (constArrays.get(t) !== undefined) return { shared: t };
  return { name: t, pattern: null, required: false };
}

function fieldsOf(body, consts) {
  const start = body.search(/fields\s*:\s*\[/);
  let parts;
  if (start < 0) {
    const ident = (body.match(/fields\s*:\s*([A-Za-z_$][A-Za-z0-9_$]*)/) || [])[1] || null;
    const shared = ident ? consts.get(ident) : undefined;
    if (shared === undefined) return ident ? [ident] : [];
    parts = splitTopLevel(shared);
  } else {
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
    parts = splitTopLevel(body.slice(body.indexOf('[', start) + 1, i));
  }
  const slots = [];
  for (const entry of parts.filter((x) => x.trim() !== '')) {
    const d = slotDetail(entry, consts);
    if (d.shared) {
      for (const sub of splitTopLevel(consts.get(d.shared)).filter((x) => x.trim() !== '')) {
        const s = slotDetail(sub, consts);
        if (!s.shared) slots.push(s);
      }
    } else {
      slots.push(d);
    }
  }
  while (slots.length < 6) slots.push({ name: '', pattern: null, required: false });
  return slots.slice(0, 6).map((s, i) => ({
    slot: i + 1,
    name: s.name ?? '',
    pattern: s.pattern ?? null,
    required: Boolean(s.required),
    maxBytes: 100,
  }));
}

// All route entries with actions, sorted by (action, method, path).
export function collectRouteContracts(rootDir) {
  const routesDir = path.join(rootDir, 'middleware', 'src', 'routes');
  const manifest = JSON.parse(readFileSync(path.join(rootDir, 'manifest', 'actions.json'), 'utf8'));
  const byAction = new Map();
  for (const a of manifest.actions || []) byAction.set(a.action, a);
  const out = [];
  for (const f of readdirSync(routesDir)
    .filter((x) => x.endsWith('.js') && x !== 'index.js')
    .sort()) {
    const src = readFileSync(path.join(routesDir, f), 'utf8');
    const consts = fileConstArrays(src);
    for (const { body } of routeObjects(src)) {
      const m = body.match(/method\s*:\s*'([a-z]+)'/);
      const p = body.match(/path\s*:\s*'([^']+)'/);
      const a = body.match(/action\s*:\s*'([A-Z0-9_]+)'/);
      if (!m || !p || !a) continue; // custom infra routes carry no action
      const hit = byAction.get(a[1]) || {};
      out.push({
        action: a[1],
        method: m[1],
        path: p[1],
        module: hit.module || null,
        prefix: hit.prefix || null,
        auth: {
          public: /\bpublic\s*:\s*true\b/.test(body),
          tokenIdentity: (body.match(/tokenIdentity\s*:\s*'([^']+)'/) || [])[1] || null,
          stepUp: /\bstepUp\s*:\s*true\b/.test(body),
          stepUpPolicy: (body.match(/stepUpPolicy\s*:\s*'([^']+)'/) || [])[1] || null,
        },
        fields: fieldsOf(body, consts),
        tested: Boolean(hit.tested),
      });
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
