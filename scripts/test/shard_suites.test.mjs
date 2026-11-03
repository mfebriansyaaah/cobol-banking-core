// Unit tests for scripts/shard_suites.mjs (no database; fixture trees only).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const PLANNER = new URL('../shard_suites.mjs', import.meta.url).pathname;

function fixture(files, baseline) {
  const root = mkdtempSync(path.join(tmpdir(), 'shard-plan-'));
  mkdirSync(path.join(root, 'tests', 'db'), { recursive: true });
  for (const f of files) writeFileSync(path.join(root, 'tests', 'db', f), '# fixture\n');
  if (baseline !== null) writeFileSync(path.join(root, 'tests', 'baseline_counts.txt'), baseline);
  return root;
}

function plan(root, ...args) {
  const out = execFileSync('node', [PLANNER, ...args, root], { encoding: 'utf8' });
  return out.trim().split('\n').filter(Boolean);
}

function loads(lines) {
  // Recompute per-shard weight sums using the name-encoded weights of the
  // LPT fixture below (mirrors the baseline file it carries).
  const m = new Map();
  for (const l of lines) {
    const [i, f] = l.split(' ');
    const w = Number(((f.split('/').pop() || '').match(/^w(\d+)_/) || [])[1] || 13);
    m.set(i, (m.get(i) || 0) + w);
  }
  return m;
}

test('every suite is assigned exactly once', () => {
  const root = fixture(
    ['a_db_tests.sh', 'b_db_tests.sh', 'c_db_tests.sh', 'd_db_tests.sh', 'e_db_tests.sh'],
    'db_x_tests=10\n',
  );
  for (const n of ['1', '2', '3', '5']) {
    const lines = plan(root, n);
    assert.equal(lines.length, 5, `all 5 suites assigned with ${n} shards`);
    const files = lines.map((l) => l.split(' ')[1]).sort();
    assert.deepEqual(files, [
      'tests/db/a_db_tests.sh',
      'tests/db/b_db_tests.sh',
      'tests/db/c_db_tests.sh',
      'tests/db/d_db_tests.sh',
      'tests/db/e_db_tests.sh',
    ]);
    const idx = lines.map((l) => Number(l.split(' ')[0]));
    assert.ok(
      idx.every((i) => i >= 0 && i < Number(n)),
      'indices in range',
    );
  }
});

test('assignment is deterministic', () => {
  const root = fixture(
    ['m_db_tests.sh', 'n_db_tests.sh', 'o_db_tests.sh'],
    'db_m_tests=40\ndb_n_tests=9\ndb_o_tests=21\n',
  );
  const a = plan(root, '2');
  const b = plan(root, '2');
  assert.deepEqual(a, b);
});

test('LPT puts the heaviest suite first and balances load', () => {
  // Weights encoded in file names for the load check below (baseline file
  // carries the real weights; the name digits mirror them).
  const root = fixture(
    ['w100_db_tests.sh', 'w90_db_tests.sh', 'w80_db_tests.sh', 'w10_db_tests.sh'],
    'db_w100_tests=100\ndb_w90_tests=90\ndb_w80_tests=80\ndb_w10_tests=10\n',
  );
  const lines = plan(root, '2');
  const first = lines[0].split(' ');
  assert.equal(first[1], 'tests/db/w100_db_tests.sh', 'heaviest suite anchors shard 0');
  const byShard = new Map();
  for (const l of lines) {
    const [i, f] = l.split(' ');
    byShard.set(i, (byShard.get(i) || []).concat(f));
  }
  // 100 alone on shard 0 would leave 90+80+10=180 vs 100; LPT must do better
  // than that: shard 0 gets 100+10=110, shard 1 gets 90+80=170.
  assert.deepEqual([...byShard.get('0')].sort(), ['tests/db/w100_db_tests.sh', 'tests/db/w10_db_tests.sh']);
  assert.deepEqual([...byShard.get('1')].sort(), ['tests/db/w80_db_tests.sh', 'tests/db/w90_db_tests.sh']);
  assert.deepEqual(loads(lines).get('0'), 110);
  assert.deepEqual(loads(lines).get('1'), 170);
});

test('--timings switches weights to measured durations', () => {
  const root = fixture(['t1_db_tests.sh', 't2_db_tests.sh'], 'db_t1_tests=1000\ndb_t2_tests=1\n');
  const baseline = plan(root, '2');
  // Baseline weights would split t1|t2 across shards (1000 vs 1).
  assert.notDeepEqual(baseline.map((l) => l.split(' ')[0]).sort(), ['0', '0'], 'baseline separates by assertion count');
  const timings = path.join(root, 'run-all.json');
  writeFileSync(
    timings,
    JSON.stringify({
      suites: [
        { suite: 't1_db_tests.sh', status: 'pass', pass: 1, fail: 0, total: 1, duration_ms: 50, shard: '0' },
        { suite: 't2_db_tests.sh', status: 'pass', pass: 1, fail: 0, total: 1, duration_ms: 9000, shard: '0' },
      ],
    }),
  );
  const timed = plan(root, '2', '--timings', timings);
  // Now t2 (9000ms) is the heavy one and anchors shard 0.
  assert.equal(timed[0].split(' ')[1], 'tests/db/t2_db_tests.sh');
});

test('missing baseline falls back to median weights', () => {
  const root = fixture(['u_db_tests.sh', 'v_db_tests.sh'], null);
  const lines = plan(root, '7');
  assert.equal(lines.length, 2);
  const files = lines.map((l) => l.split(' ')[1]).sort();
  assert.deepEqual(files, ['tests/db/u_db_tests.sh', 'tests/db/v_db_tests.sh']);
});

test('unreadable timings fall back to baseline with a note', () => {
  const root = fixture(['w_db_tests.sh'], 'db_w_tests=7\n');
  const plain = plan(root, '1');
  const r = spawnSync('node', [PLANNER, '1', root, '--timings', path.join(root, 'nope.json')], { encoding: 'utf8' });
  assert.equal(r.status, 0);
  assert.match(String(r.stderr), /using baseline weights/);
  assert.deepEqual(String(r.stdout).trim().split('\n'), plain);
});

test('output lines are stable <index> <path> pairs', () => {
  const root = fixture(['z_db_tests.sh'], null);
  const lines = plan(root, '1');
  assert.equal(lines.length, 1);
  assert.match(lines[0], /^\d+ tests\/db\/z_db_tests\.sh$/);
});
