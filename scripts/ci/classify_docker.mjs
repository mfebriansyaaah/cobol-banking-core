// Docker relevance classifier for the production image gate.
//
// `docker_relevant` is true when the change set can affect `docker build`
// (Dockerfile, build inputs, or any COPY source). Anything else — docs,
// tests, workflows, non-build scripts — means the image is provably
// identical, so `docker-build` may skip on PRs (push to main always builds).
//
// An empty change set is relevant (fail safe: cannot tell). Unknown paths
// are NOT relevant: the Dockerfile only copies the paths below, so a file
// outside them cannot change the image without a Dockerfile change (which
// itself is relevant).
//
// Usage:
//   printf '%s\n' <files> | node scripts/ci/classify_docker.mjs --stdin
// Always exits 0 and prints `docker_relevant=true|false`.
// Pure function (isDockerRelevant) is imported by
// scripts/test/classify_docker.test.mjs.
const DOCKER_FILES = new Set([
  'Dockerfile',
  '.dockerignore',
  'build.sh',
  'cobol/Makefile',
  'scripts/ci/install_gnucobol.sh',
  'middleware/package.json',
  'middleware/package-lock.json',
]);

const DOCKER_PREFIXES = [
  'cobol/',
  'middleware/src/',
  'middleware/contract/',
  'middleware/core-client/',
  'middleware/adapters/',
  'middleware/services/',
  'middleware/workers/',
  'middleware/telemetry/',
];

/** True when at least one path can change the production image. */
export function isDockerRelevant(files) {
  const list = (files || []).map((f) => String(f).trim()).filter(Boolean);
  if (!list.length) return true;
  return list.some((f) => DOCKER_FILES.has(f) || DOCKER_PREFIXES.some((p) => f.startsWith(p)));
}

/**
 * True when the image *assembly* changed, not merely its compiled sources.
 * PRs use this to skip the Docker job when `build` already compiled the same
 * code; push-to-main still validates the image unconditionally.
 */
export function isDockerDefinitionChanged(files) {
  const list = (files || []).map((f) => String(f).trim()).filter(Boolean);
  if (!list.length) return true;
  return list.some((f) => DOCKER_FILES.has(f));
}

function readStdin() {
  return new Promise((resolve, reject) => {
    let s = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => {
      s += c;
    });
    process.stdin.on('end', () => resolve(s));
    process.stdin.on('error', reject);
  });
}

const args = process.argv.slice(2);
if (import.meta.url === `file://${process.argv[1]}`) {
  const run = async () => {
    let files = args.filter((a) => a !== '--stdin' && a !== '--help' && a !== '-h');
    if (args.includes('--help') || args.includes('-h')) {
      console.log('usage: classify_docker.mjs [--stdin] [files...]');
      process.exit(0);
    }
    if (args.includes('--stdin')) {
      const raw = await readStdin();
      files = [...files, ...raw.split('\n')];
    }
    console.log(`docker_relevant=${isDockerRelevant(files)}`);
    console.log(`docker_definition=${isDockerDefinitionChanged(files)}`);
    process.exit(0);
  };
  run();
}
