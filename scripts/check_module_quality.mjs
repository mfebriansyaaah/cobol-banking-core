// Module quality gate (audit P1-08): manifest/module_quality.json must match
// the tree; recommendedForTraining must be true only for ACTIVE/PILOT
// L2/L3 non-clone modules.
// Usage: node scripts/check_module_quality.mjs [--root DIR]
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] && !process.argv[2].startsWith('--') ? process.argv[2] : '.');

try {
  const out = execFileSync(
    process.execPath,
    [path.join(root, 'scripts', 'build_module_quality.mjs'), '--check', '--root', root],
    {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );
  console.log(out.trim());
} catch (e) {
  process.stderr.write(String((e && e.stdout) || '') + String((e && e.stderr) || e.message || e));
  process.exit(typeof e?.status === 'number' ? e.status : 1);
}

const recorded = JSON.parse(readFileSync(path.join(root, 'manifest', 'module_quality.json'), 'utf8'));
const seen = new Set();
for (const m of recorded.modules || []) {
  if (seen.has(m.module)) {
    console.error(`FAIL: duplicate module: ${m.module}`);
    process.exit(1);
  }
  seen.add(m.module);
  const expectRecommended =
    (m.domainStatus === 'ACTIVE' || m.domainStatus === 'PILOT') &&
    (m.linkageLevel === 'L2' || m.linkageLevel === 'L3') &&
    !(m.cloneSimilarity !== null && m.cloneSimilarity >= 0.9);
  if (m.recommendedForTraining !== expectRecommended) {
    console.error(`FAIL: ${m.module}: recommendedForTraining must be ${expectRecommended}`);
    process.exit(1);
  }
}
console.log(`OK: ${seen.size} modules`);
