// Docker pin gate (P1-11): production Dockerfile must not float on
// mutable tags. Every FROM must name an immutable tag (no :latest,
// no untagged image). Digests are intentionally not required: they cannot
// be resolved or verified in this environment, so a digest here would be
// an unverifiable claim (see the Dockerfile header note); CI build logs
// record the resolved digest instead.
// Usage: node scripts/check_docker_pins.mjs [root]
// Exit: 0 ok, 1 violation, 2 usage error.
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let root = '.';
for (const a of args) {
  if (a === '--help' || a === '-h') {
    console.log('usage: check_docker_pins.mjs [root]');
    process.exit(0);
  } else if (a.startsWith('--')) {
    console.error(`unknown argument: ${a}`);
    process.exit(2);
  } else root = a;
}
root = path.resolve(root);

const file = path.join(root, 'Dockerfile');
if (!existsSync(file)) {
  console.error('FAIL: Dockerfile missing (P1-11 production image)');
  process.exit(1);
}
const errors = [];
const src = readFileSync(file, 'utf8');
const froms = [...src.matchAll(/^\s*FROM\s+(\S+)/gm)].map((m) => m[1]);
if (froms.length === 0) {
  console.error('FAIL: Dockerfile has no FROM lines');
  process.exit(1);
}
for (const image of froms) {
  const name = image.split('@')[0];
  if (/:latest$/.test(name) || !name.includes(':')) {
    errors.push(`${image}: floating tag (pin an immutable tag, never :latest or untagged)`);
  }
}

if (errors.length) {
  console.error('DOCKER-PIN VIOLATIONS:');
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}
console.log(`OK: ${froms.length} base image(s) pinned by immutable tag (${froms.join(', ')})`);
