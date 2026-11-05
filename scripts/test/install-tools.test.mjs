// Unit tests for scripts/ci/install-tools.sh and .gitleaks.toml (CI-012).
//
// The installer must verify checksums BEFORE extraction: a corrupted tarball
// (or a wrong hash) fails and leaves the destination empty. Fixtures live in
// tests/fixtures/install-tools/ and are fetched through file:// URLs, so no
// network is needed. Gitleaks behavior is tested when the binary exists;
// the allowlist shape is always asserted statically.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const INSTALLER = path.join(ROOT, 'scripts', 'ci', 'install-tools.sh');
const FIXTURE_BASE = path.join(ROOT, 'tests', 'fixtures', 'install-tools', 'actionlint');
const VALID_TGZ = path.join(FIXTURE_BASE, 'v1.7.7', 'actionlint_1.7.7_linux_amd64.tar.gz');
const CORRUPT_TGZ = `${VALID_TGZ}.corrupt`;

const sha256File = (p) => createHash('sha256').update(readFileSync(p)).digest('hex');

function install({ ver, base, sha, only = 'actionlint' }) {
  const dest = mkdtempSync(path.join(tmpdir(), 'install-tools-'));
  try {
    execFileSync('bash', [INSTALLER, '--dest', dest, '--only', only], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: 120000,
      env: {
        ...process.env,
        ACTIONLINT_VER: ver,
        ACTIONLINT_BASE: base,
        ACTIONLINT_SHA256: sha,
      },
    });
    return { status: 0, dest };
  } catch (e) {
    return { status: typeof e?.status === 'number' ? e.status : 1, dest, output: String(e?.stderr || e) };
  }
}

test('checksum mismatch fails before extraction and leaves dest empty', () => {
  const r = install({ ver: '1.7.7', base: `file://${FIXTURE_BASE}`, sha: '0'.repeat(64) });
  assert.notEqual(r.status, 0, 'wrong hash must fail');
  assert.deepEqual(readdirSync(r.dest), [], 'nothing may be extracted on mismatch');
});

test('valid fixture installs the binary', () => {
  const r = install({ ver: '1.7.7', base: `file://${FIXTURE_BASE}`, sha: sha256File(VALID_TGZ) });
  assert.equal(r.status, 0, r.output || '');
  assert.deepEqual(readdirSync(r.dest), ['actionlint']);
});

test('unknown tool name is rejected', () => {
  const r = install({ ver: '1', base: `file://${FIXTURE_BASE}`, sha: '0'.repeat(64), only: 'no-such-tool' });
  assert.notEqual(r.status, 0, 'unknown tool must fail');
});

test('tool-checksums.txt pins every installer tool with a 64-hex hash', () => {
  const src = readFileSync(path.join(ROOT, 'scripts', 'ci', 'tool-checksums.txt'), 'utf8');
  const entries = new Map();
  for (const line of src.split('\n')) {
    const m = line.match(/^([0-9a-f]{64})\s+(\S+)\s*$/);
    if (m) entries.set(m[2], m[1]);
  }
  for (const f of [
    'shellcheck-v0.10.0.linux.x86_64.tar.xz',
    'shfmt_v3.11.0_linux_amd64',
    'actionlint_1.7.7_linux_amd64.tar.gz',
    'prometheus-3.3.1.linux-amd64.tar.gz',
    'gitleaks_8.28.0_linux_x64.tar.gz',
  ]) {
    assert.ok(entries.has(f), `missing checksum entry for ${f}`);
  }
});

test('.gitleaks.toml has no path-wide exemption', () => {
  const src = readFileSync(path.join(ROOT, '.gitleaks.toml'), 'utf8');
  assert.ok(!/^\s*paths\s*=/m.test(src), 'path-wide allowlist must go');
  assert.ok(/allowlist/.test(src), 'regex allowlist for migration checksums stays');
  assert.ok(
    /regexTarget\s*=\s*"match"/.test(src),
    'regex targets the matched span (gitleaks matches name+hash, not the full line)',
  );
});

function haveGitleaks() {
  try {
    execFileSync('gitleaks', ['version'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 30000 });
    return true;
  } catch {
    return false;
  }
}

test(
  'gitleaks redacts findings instead of printing secrets',
  { skip: !haveGitleaks() && 'gitleaks binary absent' },
  () => {
    const dir = mkdtempSync(path.join(tmpdir(), 'gitleaks-'));
    const secret = `token = "xoxb-test-secret-${Date.now()}"`;
    writeFileSync(path.join(dir, 'leak.txt'), `${secret}\n`);
    let status = 0;
    let out = '';
    try {
      execFileSync(
        'gitleaks',
        ['detect', '--source', dir, '--no-git', '--config', path.join(ROOT, '.gitleaks.toml'), '--redact', '--verbose'],
        { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 120000 },
      );
    } catch (e) {
      status = typeof e?.status === 'number' ? e.status : 1;
      out = String(e?.stdout || '') + String(e?.stderr || '');
    }
    assert.equal(status, 1, 'a finding must fail the scan');
    assert.ok(!out.includes('xoxb-test-secret-'), 'the secret value must not appear (redacted)');
  },
);
