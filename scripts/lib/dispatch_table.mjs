// Parser for the table-driven dispatcher in cobol/src/main_logic.cob.
//
// The dispatcher is three parallel MOVE lists keyed by slot index:
//   MOVE "<PREFIX>"      TO D-PREFIX(n)
//   MOVE <len>           TO D-PREFIX-LEN(n)
//   MOVE "<program>"     TO D-PROGRAM(n)
//
// Both the manifest generator and the manifest checker use this function so
// there is exactly one definition of "what the dispatcher contains". Keeping
// two parsers was how the manifest silently went empty when main_logic.cob
// moved from an IF-chain to a table.

export function parseDispatchTable(source) {
  const prefixes = new Map();
  const prefixLens = new Map();
  const programs = new Map();

  for (const m of source.matchAll(/MOVE\s+"([^"]+)"\s+TO\s+D-PREFIX\((\d+)\)/g)) {
    prefixes.set(Number(m[2]), m[1]);
  }
  for (const m of source.matchAll(/MOVE\s+(\d+)\s+TO\s+D-PREFIX-LEN\((\d+)\)/g)) {
    prefixLens.set(Number(m[2]), Number(m[1]));
  }
  for (const m of source.matchAll(/MOVE\s+"([^"]+)"\s+TO\s+D-PROGRAM\((\d+)\)/g)) {
    programs.set(Number(m[2]), m[1]);
  }

  const slots = [...prefixes.keys()].sort((a, b) => a - b);
  const entries = [];
  const problems = [];

  for (const slot of slots) {
    const prefix = prefixes.get(slot);
    const program = programs.get(slot);
    if (!program) {
      problems.push(`slot ${slot} ("${prefix}") has no D-PROGRAM assignment`);
      continue;
    }
    const declaredLen = prefixLens.get(slot);
    if (declaredLen === undefined) {
      problems.push(`slot ${slot} ("${prefix}") has no D-PREFIX-LEN assignment`);
      continue;
    }
    entries.push({ prefixLen: declaredLen, prefix, program });
  }

  // CMD-ACTION and D-PREFIX are space-padded fixed-width fields, so a declared
  // length larger than the literal still compares correctly (the extra
  // positions are spaces on both sides). A declared length *shorter* than the
  // literal is the dangerous case: it under-specifies the prefix and can route
  // an action to a module that merely shares a stem.
  const cmdAction = source.match(/CMD-ACTION\s+PIC\s+X\((\d+)\)/);
  const prefixField = source.match(/D-PREFIX\s+PIC\s+X\((\d+)\)/);
  const actionWidth = cmdAction ? Number(cmdAction[1]) : 20;
  const prefixWidth = prefixField ? Number(prefixField[1]) : actionWidth;

  for (const e of entries) {
    if (e.prefix.length > prefixWidth) {
      problems.push(
        `slot prefix "${e.prefix}" is ${e.prefix.length} characters but D-PREFIX is PIC X(${prefixWidth})`
      );
    }
    if (e.prefixLen < e.prefix.length) {
      problems.push(
        `slot prefix "${e.prefix}" declares length ${e.prefixLen}, shorter than the literal (${e.prefix.length}); the match is under-specified`
      );
    }
    if (e.prefixLen > prefixWidth) {
      problems.push(
        `slot prefix "${e.prefix}" declares length ${e.prefixLen}, past the D-PREFIX field width (${prefixWidth})`
      );
    }
  }

  const seen = new Map();
  for (const e of entries) {
    if (seen.has(e.prefix)) {
      problems.push(`duplicate dispatch prefix "${e.prefix}" (slots share a prefix)`);
    }
    seen.set(e.prefix, true);
  }

  return { entries, problems };
}
