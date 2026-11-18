# Deployment — Production Image

The production runtime is a single container image plus an external
MariaDB/MySQL database. Migrations run separately under a privileged
account; the running container only gets DML rights.

```sh
# Build (records the resolved base-image digests in the build log).
docker build -f Dockerfile -t cobol-banking-core:prod .

# Migrate (privileged account, run before the first start and on upgrades).
DB_HOST=... DB_USER=cobol_migrate DB_PASS=... DB_NAME=cobol_db \
  ./database/migrate.sh

# Run (non-root inside the image; production guards refuse weak secrets
# and development database defaults — see middleware/.env.example).
docker run -d --name bank \
  -p 3000:3000 \
  -e NODE_ENV=production \
  -e JWT_SECRET=... -e REFRESH_SECRET=... \
  -e DB_HOST=... -e DB_USER=cobol_app -e DB_PASS=... -e DB_NAME=cobol_db \
  -e REDIS_URL=... \
  cobol-banking-core:prod

# Health: /live (no auth), /ready (dependency check), /metrics (bearer).
curl localhost:3000/live
```

## What the image contains

- Stage 1 builds GnuCOBOL 3.2 from the pinned tarball + SHA-256 in
  `scripts/ci/install_gnucobol.sh` (the same script the coverage CI jobs
  use), compiles every `cobol/src/*_core.cob` via `./build.sh`, and fails
  the build when `ldd` reports a missing native library.
- Stage 2 installs gateway dependencies with `npm ci --omit=dev` against
  `middleware/package-lock.json` (reproducible, no dev tools).
- Stage 3 (`node:24-bookworm-slim`) ships the binary, `libmariadb3`, the
  gateway, and nothing else: no tests, no specs, no preloads, no
  build context (see `.dockerignore`). It runs as uid 10001.
- `COBOL_BIN=/app/cobol/bin/main_logic` is baked in; production defaults
  to the worker pool (4 workers × 2 in-flight, see `middleware/src/server.js`).

## What the image needs from the operator

| Setting                                                    | Source         | Notes                                                                       |
| ---------------------------------------------------------- | -------------- | --------------------------------------------------------------------------- |
| `JWT_SECRET`, `REFRESH_SECRET`                             | secret manager | ≥32 chars each, must differ; startup refuses otherwise                      |
| `DB_HOST/PORT/USER/PASS/NAME`                              | secret manager | DML-only `cobol_app`; never bake into the image                             |
| `REDIS_URL`                                                | platform       | shared rate-limit counters across replicas                                  |
| `SMTP_*`, `NIK_HMAC_SECRET`, `VAULT_*`, `TURNSTILE_SECRET` | secret manager | only the ones the configured providers need (see `middleware/.env.example`) |

`.env` files are development-only and never enter the image (see
`.dockerignore` and `docs/INTEGRATION_HARDENING.md`).

## Known residuals (not blockers for the image itself)

- Base images are pinned by immutable tag, not digest
  (`scripts/check_docker_pins.mjs` enforces no `:latest`). Digests cannot
  be resolved or verified in this environment, so a digest here would be
  an unverifiable claim; record the built digest from CI logs instead.
- The dev vault (`quay.io/minio/minio:latest` in
  `docker-compose.test.yml`) is unpinned for the same reason (quay.io
  needs auth for anonymous manifest inspection). Production needs
  distributed MinIO plus a real KMS key (see `docs/PRODUCTION_READINESS.md`
  and `docs/runbooks/vault-kms.md`).
- The image is built, not yet run, in CI (`docker-build` job): it proves
  the Dockerfile compiles and links. A staging run with a real database
  plus the canary exercise stays open (see Reliability in
  `docs/PRODUCTION_READINESS.md`).
