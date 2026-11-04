// Template UPDATE test generator (T-016A spike outcome: GO).
//
// Appends an UPDATE test block to a template DB suite by parsing what the
// suite and the routes already say: the CREATE sample values, the CREATE and
// UPDATE field-name lists, and the suite's reset/table names. UPDATE slots
// are filled by field NAME (ID -> ${id}, ACTOR -> admin@test.com,
// BLANK -> empty, other names -> the CREATE sample for the same name).
// Domains that do not fit the template shape are SKIPPED with a reason
// (manual queue) instead of emitting a wrong test.
//
// Discovered shape (verified live on account/cost_center, 243/244 cat-1
// UPDATE actions share it): 6 slots [ID, f1, f2, BLANK, BLANK, ACTOR],
// version-checked UPDATE, audit row with action='UPDATE', missing id ->
// NOT_FOUND, non-admin -> FORBIDDEN. There is NO client-visible version
// conflict: LOAD-CLEARING reads the current version, so concurrent updates
// are last-writer-wins (pinned by the version-bump assertion, not by a
// conflict path that does not exist).
//
// Usage:
//   node scripts/generate_domain_tests.mjs [--root DIR] [--verify-db] <stem>...
// Exit: 0 all emitted (or already present), 1 usage error,
//       2 one or more domains skipped for the manual queue.
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

// Pure argument parsing (no process.exit): the CLI runner below decides the
// exit code, so unit tests can import this module safely.
function parseCli(argv) {
  let root = '.';
  let verifyDb = false;
  const stems = [];
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root') {
      root = argv[i + 1] ?? root;
      i += 1;
    } else if (a === '--verify-db') verifyDb = true;
    else if (a === '--help' || a === '-h') return { help: true };
    else if (a.startsWith('--')) throw new Error(`unknown argument: ${a}`);
    else stems.push(a);
  }
  return { root: path.resolve(root), verifyDb, stems };
}

const MARKER = '# UPDATE (optimistic locking: version bump + audit).';

function failSkip(stem, reason) {
  console.error(`SKIP ${stem}: ${reason}`);
  return { stem, ok: false, reason };
}

function parseRouteFields(routeSrc, action) {
  const re =
    /\{\s*method:\s*'(\w+)'\s*,\s*path:\s*'([^']+)'\s*,\s*action:\s*'([A-Z0-9_]+)'\s*(?:,\s*tokenIdentity:[^,}]+)?\s*,\s*fields:\s*\[([\s\S]*?)\]\s*\}/g;
  let m;
  while ((m = re.exec(routeSrc)) !== null) {
    if (m[3] !== action) continue;
    const names = [];
    // Object slots contribute their name:; bare UPPER_SNAKE constants
    // contribute themselves (ID, BLANK, ACTOR, LIMIT, DATE_FIELD, ...).
    // Dotted paths (PATTERNS.X) carry no field name and are skipped.
    const tok = /\{[^{}]*name:\s*'([^']+)'[^{}]*\}|([A-Za-z_$][\w$]*)(\s*\.\s*[A-Za-z_$][\w$]*)*/g;
    let t;
    while ((t = tok.exec(m[4])) !== null) {
      if (t[1] !== undefined) names.push(t[1]);
      else if (!t[0].includes('.') && /^[A-Z]/.test(t[2])) names.push(t[2]);
    }
    return names;
  }
  return null;
}

function parseSuite(suiteSrc, prefix) {
  const createRe = new RegExp(`run_cobol\\s+"${prefix}_CREATE\\|([^"]*)"`);
  const m = suiteSrc.match(createRe);
  if (!m) return { error: 'no CREATE invocation found' };
  const createArgs = m[1].split('|');
  const resetM = suiteSrc.match(/^\s*db_reset_(\w+)\s*$/m);
  const idM = suiteSrc.match(/^\s*id="\$\(printf[^)]*\)"\s*$/m);
  return {
    createArgs,
    table: resetM ? resetM[1] : null,
    hasIdVar: Boolean(idM),
  };
}

function parseAuditFk(cobSrc, table) {
  // The audit FK column is the first column of the audit INSERT
  // (usually <table>_id, but e.g. cost_center_audit uses cc_id).
  // Parsed from COBOL source, never guessed.
  const m = cobSrc.match(new RegExp(`INSERT INTO ${table}_audit \\(([^)]*)\\)`, 'i'));
  if (!m) return null;
  return m[1].split(',')[0].trim().replace(/[`"]/g, '');
}

function buildBlock({ prefix, table, actor, updateArgs, fk }) {
  // Version/audit assertions are relative (+1): template suites already bump
  // the version through CALC/CLOSE before this block runs, so absolute
  // values would couple the block to suite order.
  const run = (input) => `run_cobol "${input}"`;
  const upd = (id, who) => `${prefix}_UPDATE|${id}|${updateArgs.join('|')}|||${who}`;
  return [
    '',
    MARKER,
    `ver_before="$(db_query "SELECT version FROM ${table} WHERE id=\${id};")"`,
    `aud_before="$(db_query "SELECT COUNT(*) FROM ${table}_audit WHERE ${fk}=\${id} AND action='UPDATE';")"`,
    `upd_out="$(${run(upd('${id}', actor))})"`,
    `assert_match "${prefix}_UPDATE ok" "$upd_out" "SUCCESS\\\\|${prefix}_UPDATE"`,
    `assert_match "version bumped" "$(db_query "SELECT version FROM ${table} WHERE id=\${id};")" "^$((ver_before + 1))$"`,
    `assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM ${table}_audit WHERE ${fk}=\${id} AND action='UPDATE';")" "^$((aud_before + 1))$"`,
    `assert_match "update missing id" "$(${run(upd('999999', actor))})" "ERROR\\\\|NOT_FOUND"`,
    `assert_match "non-admin update refused" "$(${run(upd('${id}', 'sender@test.com'))})" "ERROR\\\\|FORBIDDEN"`,
  ].join('\n');
}

function dbQuery(sql) {
  const out = execFileSync(
    'mysql',
    [
      '-h',
      process.env.DB_HOST || 'localhost',
      '-P',
      process.env.DB_PORT || '3306',
      '-u',
      process.env.DB_USER || 'cobol_user',
      `-p${process.env.DB_PASS || 'cobol_pass'}`,
      process.env.DB_NAME || 'cobol_db',
      '-N',
      '-B',
      '-e',
      sql,
    ],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] },
  );
  return out.trim();
}

function planDomain(stem, opts = {}) {
  const r = opts.root || process.cwd();
  const suitePath = path.join(r, 'tests', 'db', `${stem}_db_tests.sh`);
  if (!existsSync(suitePath)) return failSkip(stem, 'no DB suite file');
  const suiteSrc = readFileSync(suitePath, 'utf8');
  if (suiteSrc.includes(MARKER)) return { stem, ok: true, skipped: true, reason: 'block already present' };

  let routeSrc = null;
  let routeFile = `middleware/src/routes/${stem}.js`;
  if (existsSync(path.join(r, routeFile))) routeSrc = readFileSync(path.join(r, routeFile), 'utf8');
  if (!routeSrc) return failSkip(stem, 'no route file middleware/src/routes/<stem>.js');

  const actions = [...new Set([...routeSrc.matchAll(/action:\s*'([A-Z0-9_]+_UPDATE)'/g)].map((m) => m[1]))];
  if (actions.length !== 1) return failSkip(stem, `expected exactly 1 *_UPDATE action, found ${actions.length}`);
  const action = actions[0];
  const prefix = action.replace(/_UPDATE$/, '');

  const suite = parseSuite(suiteSrc, prefix);
  if (suite.error) return failSkip(stem, suite.error);
  if (!suite.table) return failSkip(stem, 'no db_reset_<table> line found');
  if (!suite.hasIdVar) return failSkip(stem, 'no id=$(...) capture found');
  const table = suite.table;

  const createFields = parseRouteFields(routeSrc, `${prefix}_CREATE`);
  const updateFields = parseRouteFields(routeSrc, action);
  if (!createFields || !updateFields) return failSkip(stem, 'CREATE or UPDATE route not parsed');
  if (updateFields.length !== 6 || updateFields[0] !== 'ID' || updateFields[5] !== 'ACTOR') {
    return failSkip(stem, `UPDATE slots are not [ID,f1,f2,BLANK,BLANK,ACTOR]: ${updateFields.join(',')}`);
  }
  const createByName = {};
  createFields.forEach((n, i) => {
    if (!(n in createByName)) createByName[n] = suite.createArgs[i] ?? '';
  });
  const updateArgs = [];
  for (const n of updateFields.slice(1, 3)) {
    if (!(n in createByName)) return failSkip(stem, `UPDATE field '${n}' has no CREATE counterpart`);
    updateArgs.push(createByName[n]);
  }
  const actor = 'admin@test.com';

  const cobPath = path.join(r, 'cobol', 'src', `${stem}_core.cob`);
  if (!existsSync(cobPath)) return failSkip(stem, 'no COBOL module cobol/src/<stem>_core.cob');
  const fk = parseAuditFk(readFileSync(cobPath, 'utf8'), table);
  if (!fk) return failSkip(stem, `no INSERT INTO ${table}_audit (...) parsed from COBOL`);

  if (opts.verifyDb) {
    const has = (q) => dbQuery(q) !== '';
    if (!has(`SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = '${table}'`)) {
      return failSkip(stem, `table ${table} missing`);
    }
    if (
      !has(
        `SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = '${table}' AND column_name = 'version'`,
      )
    ) {
      return failSkip(stem, `table ${table} has no version column`);
    }
    if (
      !has(`SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = '${table}_audit'`)
    ) {
      return failSkip(stem, `audit table ${table}_audit missing`);
    }
    if (
      !has(
        `SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = '${table}_audit' AND column_name = '${fk}'`,
      )
    ) {
      return failSkip(stem, `audit table ${table}_audit has no column ${fk}`);
    }
  }

  const block = buildBlock({ prefix, table, actor, updateArgs, fk });
  return { stem, ok: true, block, routeFile, prefix, table };
}

export { parseRouteFields, parseSuite, parseAuditFk, buildBlock, planDomain, parseCli };

// ---- CLI ----
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname)) {
  let cli;
  try {
    cli = parseCli(process.argv.slice(2));
  } catch (e) {
    console.error(e.message);
    console.error('usage: generate_domain_tests.mjs [--root DIR] [--verify-db] <stem>...');
    process.exit(2);
  }
  if (cli.help || !cli.stems.length) {
    console.log('usage: generate_domain_tests.mjs [--root DIR] [--verify-db] <stem>...');
    process.exit(cli.help ? 0 : 2);
  }
  const { root, verifyDb, stems } = cli;
  let failed = false;
  for (const stem of stems) {
    const plan = planDomain(stem, { verifyDb });
    if (!plan.ok || plan.skipped) {
      if (plan.skipped) console.log(`SKIP ${stem}: ${plan.reason} (already present)`);
      else failed = true;
      continue;
    }
    const suitePath = path.join(root, 'tests', 'db', `${stem}_db_tests.sh`);
    const src = readFileSync(suitePath, 'utf8');
    const anchor = 'print_summary';
    if (!src.includes(anchor)) {
      console.error(`SKIP ${stem}: no print_summary anchor`);
      failed = true;
      continue;
    }
    writeFileSync(suitePath, src.replace(anchor, `${plan.block}\n\n${anchor}`));
    console.log(`OK ${stem}: UPDATE block appended (${plan.prefix}_UPDATE on ${plan.table})`);
  }
  if (failed) {
    console.error('\nSome domains need manual handling (see SKIP lines above).');
    process.exit(2);
  }
}
