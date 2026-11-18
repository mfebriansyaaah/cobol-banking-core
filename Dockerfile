# Production image for cobol-banking-core.
#
# What runs where:
#   - COBOL is the authoritative business tier (balances, limits, ledger).
#   - Node/Express is transport only; C is the MySQL bridge.
#   - The image ships the compiled COBOL binary plus the gateway.
#     The database is external (see docs/DEPLOYMENT.md).
#
# Reproducibility:
#   - GnuCOBOL comes from the pinned tarball + SHA-256 in
#     scripts/ci/install_gnucobol.sh (same script the coverage CI jobs
#     use), not from apt (whose major version drifts per runner).
#   - Base images are pinned by immutable tags (no :latest anywhere;
#     enforced by scripts/check_docker_pins.mjs).
#   - Digests are deliberately NOT pinned here: they cannot be resolved or
#     verified in this environment (no registry auth), so a digest would be
#     an unverifiable claim. Record the built digest from CI logs instead.
#
# Build: docker build -f Dockerfile -t cobol-banking-core:prod .
# Run:   see docs/DEPLOYMENT.md (production env/secrets required).

# --- Stage 1: build the COBOL binary + C bridge ---------------------------
FROM debian:bookworm-slim AS cobol-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential curl ca-certificates libgmp-dev libmysqlclient-dev \
 && rm -rf /var/lib/apt/lists/*

# Pinned GnuCOBOL 3.2 (checksum enforced inside the script).
COPY scripts/ci/install_gnucobol.sh /tmp/install_gnucobol.sh
RUN bash /tmp/install_gnucobol.sh 3.2 /opt/gnucobol \
 && /opt/gnucobol/bin/cobc --version
ENV PATH=/opt/gnucobol/bin:$PATH \
    LD_LIBRARY_PATH=/opt/gnucobol/lib

WORKDIR /src
COPY cobol/ ./cobol/
COPY build.sh ./build.sh
COPY cobol/Makefile ./cobol/Makefile
RUN ./build.sh \
 && test -x cobol/bin/main_logic \
 && if ldd cobol/bin/main_logic | grep -q "not found"; then echo "missing native libraries" >&2; ldd cobol/bin/main_logic >&2; exit 1; fi

# --- Stage 2: install gateway dependencies --------------------------------
FROM node:24-bookworm-slim AS gateway-deps

WORKDIR /src
COPY middleware/package.json middleware/package-lock.json ./middleware/
RUN npm ci --omit=dev --no-audit --no-fund --prefix middleware

# --- Stage 3: production runtime -------------------------------------------
FROM node:24-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends libmariadb3 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=cobol-builder /opt/gnucobol /opt/gnucobol
COPY --from=cobol-builder /src/cobol/bin/main_logic /app/cobol/bin/main_logic
COPY --from=gateway-deps /src/middleware/node_modules /app/middleware/node_modules
COPY middleware/package.json /app/middleware/package.json
COPY middleware/src/ /app/middleware/src/
COPY middleware/contract/ /app/middleware/contract/
COPY middleware/core-client/ /app/middleware/core-client/
COPY middleware/adapters/ /app/middleware/adapters/
COPY middleware/services/ /app/middleware/services/
COPY middleware/workers/ /app/middleware/workers/
COPY middleware/telemetry/ /app/middleware/telemetry/

ENV LD_LIBRARY_PATH=/opt/gnucobol/lib \
    NODE_ENV=production \
    COBOL_BIN=/app/cobol/bin/main_logic

RUN useradd -r -u 10001 appuser \
 && chown -R appuser:appuser /app /opt/gnucobol
USER appuser
WORKDIR /app
EXPOSE 3000

# Liveness probe (no dependencies, no auth) — see middleware/src/app.js.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/live').then(function(r){if(!r.ok)process.exit(1)}).catch(function(){process.exit(1)})"

CMD ["node", "middleware/src/server.js"]
