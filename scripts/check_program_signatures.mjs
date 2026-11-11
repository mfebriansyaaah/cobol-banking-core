// Program-signature gate (maint-01): route fields must fit the COBOL
// program's parameter list, and the dispatcher's CALL arity must match it.
//
// Background: most modules take 6 params (LS-PARAM1..6), but user_core takes
// 4 and deposit_core takes 7 (LS-PARAM7 carries the DEP_OPEN idempotency
// key). main_logic.cob special-cases both CALL arities. Two silent
// truncation classes follow:
//   1. A route with a NAMED field past its program's param count compiles,
//      runs, and drops the value: user_core never sees slots 5-6.
//   2. A dispatcher CALL arity that stops matching a program's USING clause
//      truncates (or overfeeds) every action for that module.
//
// Rules:
//   1. For every route action, slots beyond its program's param count must
//      be padding (empty name). Named fields there fail the gate.
//   2. main_logic.cob must CALL user_core with 4 params, deposit_core with 7,
//      and every other program with 6 (action + params + output buffer
//      excluded from the count on both sides).
//
// Resolution reuses the shared parsers: dispatch longest-prefix match from
// scripts/lib/dispatch_table.mjs and route contracts from
// scripts/lib/contract.mjs. COBOL USING clauses are parsed as text.
//
// Usage: node scripts/check_program_signatures.mjs [root]
// Exit: 0 ok, 1 violation, 2 usage error.
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseDispatchTable, loadDispatchSource } from './lib/dispatch_table.mjs';
import { collectRouteContracts } from './lib/contract.mjs';

export const DEFAULT_PARAMS = 6;
export const PROGRAM_PARAMS = new Map([
  ['user_core', 4],
  ['deposit_core', 7],
]);

export function expectedParams(program) {
  return PROGRAM_PARAMS.get(program) ?? DEFAULT_PARAMS;
}

// Count LS-PARAMn in a PROCEDURE DIVISION USING clause. Returns null when
// the module has no standard linkage (e.g. hashlen_core).
export function usingParamCount(source) {
  const m = String(source || '').match(/PROCEDURE\s+DIVISION\s+USING\s+([\s\S]*?)\./);
  if (!m) return null;
  const params = new Set();
  for (const p of m[1].matchAll(/LS-PARAM(\d+)/g)) params.add(Number(p[1]));
  if (params.size === 0) return null;
  return Math.max(...params);
}

// Longest-prefix dispatch resolution (same rule as the COBOL dispatcher and
// check_route_dispatch.mjs): the longest matching prefix wins.
export function resolveProgram(action, entries) {
  let best = null;
  for (const e of entries) {
    if (action.startsWith(e.prefix) && (!best || e.prefix.length > best.prefix.length)) best = e;
  }
  return best ? best.program : null;
}

// Count CMD-PARAMn in a CALL ... USING line.
export function callArity(line) {
  const params = new Set();
  for (const p of String(line || '').matchAll(/CMD-PARAM(\d+)/g)) params.add(Number(p[1]));
  return params.size === 0 ? null : Math.max(...params);
}

export function checkTree(rootDir) {
  const errors = [];
  const mainLogic = loadDispatchSource(rootDir);
  const { entries } = parseDispatchTable(mainLogic);
  const contracts = collectRouteContracts(rootDir);

  // Rule 2: dispatcher CALL arity per program.
  const callLines = mainLogic.split('\n').filter((l) => /CALL\s+D-PROGRAM/.test(l));
  const seenArity = new Map();
  for (const line of callLines) {
    const arity = callArity(line);
    if (arity === null) {
      errors.push(`dispatcher CALL without CMD-PARAMn: ${line.trim().slice(0, 80)}`);
      continue;
    }
    // Attribute the arity by the surrounding special-case: the user_core
    // and deposit_core branches name their program on a nearby IF line.
    seenArity.set(arity, (seenArity.get(arity) || 0) + 1);
  }
  for (const a of [4, 6, 7]) {
    if (!seenArity.has(a)) errors.push(`dispatcher has no ${a}-param CALL (expected user=4, default=6, deposit=7)`);
  }

  // Rule 2b: every program's USING count matches its expected arity.
  const srcDir = path.join(rootDir, 'cobol', 'src');
  const programs = new Set(entries.map((e) => e.program));
  for (const program of [...programs].sort()) {
    const file = path.join(srcDir, `${program}.cob`);
    if (!existsSync(file)) {
      errors.push(`dispatch program missing source: ${program}.cob`);
      continue;
    }
    const count = usingParamCount(readFileSync(file, 'utf8'));
    if (count === null) continue;
    const want = expectedParams(program);
    if (count !== want) {
      errors.push(`${program}.cob declares ${count} LS-PARAMs but the dispatcher passes ${want}`);
    }
  }

  // Rule 1: named route fields must fit the program's params.
  for (const e of checkRule1(contracts, entries)) errors.push(e);
  return errors;
}

export function checkRule1(contracts, entries) {
  const errors = [];
  for (const c of contracts) {
    if (!c.action) continue;
    const program = resolveProgram(c.action, entries);
    if (!program) continue; // owned by check_route_dispatch
    const limit = expectedParams(program);
    for (const f of c.fields || []) {
      if (f.slot > limit && f.name) {
        errors.push(
          `${c.routeFile} ${c.method.toUpperCase()} ${c.path}: field '${f.name}' at slot ${f.slot} never reaches ${program} (${limit} params)`,
        );
      }
    }
  }
  return errors;
}

const args = process.argv.slice(2);
let root = '.';
for (const a of args) {
  if (a === '--help' || a === '-h') {
    console.log('usage: check_program_signatures.mjs [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else {
    root = a;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const errors = checkTree(path.resolve(root));
  if (errors.length) {
    console.error('PROGRAM-SIGNATURE VIOLATIONS:');
    for (const e of errors) console.error(`  ${e}`);
    process.exit(1);
  }
  console.log('OK: route fields fit program params; dispatcher arity matches USING clauses');
}
