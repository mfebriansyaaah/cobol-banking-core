#!/usr/bin/env bash
# Checksum-verified installer for CI lint tools (CI-012).
#
# Downloads shellcheck, shfmt, actionlint, promtool, and gitleaks, verifies
# every file against scripts/ci/tool-checksums.txt BEFORE extraction, and
# only then installs into --dest. A checksum mismatch (or an unknown version
# with no pinned hash) fails before anything lands on PATH.
#
# Versions default to the CI pins; override one with <TOOL>_VER
# (e.g. SC_VER=0.10.0). Download bases default to the release URLs; override
# one with <TOOL>_BASE for tests (e.g. file:// fixture URLs). Per-file hashes
# default to tool-checksums.txt; override one with <TOOL>_SHA256 for tests.
#
# Usage: bash scripts/ci/install-tools.sh --dest DIR [--only a,b]
#   --only limits to: shellcheck, shfmt, actionlint, promtool, gitleaks.
set -euo pipefail

DEST=""
ONLY="shellcheck,shfmt,actionlint,promtool,gitleaks"
need_arg() {
    if [ -n "${2:-}" ]; then
        printf '%s' "$2"
    else
        echo "usage: $0 --dest DIR [--only a,b]" >&2
        exit 2
    fi
}
while [ $# -gt 0 ]; do
    case "$1" in
        --dest) DEST="$(need_arg "$1" "${2:-}")"; shift 2 ;;
        --dest=*) DEST="${1#--dest=}"; shift ;;
        --only) ONLY="$(need_arg "$1" "${2:-}")"; shift 2 ;;
        --only=*) ONLY="${1#--only=}"; shift ;;
        --help|-h) sed -n '2,/^set -euo pipefail$/p' "$0" | sed '$d'; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ -n "$DEST" ] || { echo "usage: $0 --dest DIR [--only a,b]" >&2; exit 2; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHECKSUMS="$ROOT/scripts/ci/tool-checksums.txt"

for cmd in curl sha256sum tar mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "FAIL: $cmd not found" >&2; exit 2; }
done
[ -f "$CHECKSUMS" ] || { echo "FAIL: missing $CHECKSUMS" >&2; exit 2; }

mkdir -p "$DEST"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/install-tools.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Pinned hash for a downloaded file name; empty when unpinned (refuse).
pinned_sha() {
    awk -v f="$1" '$2 == f { print $1; exit }' "$CHECKSUMS"
}

# Download, verify, then extract into $DEST. Never touches $DEST before the
# checksum matches.
fetch_verified() { # $1 = url, $2 = file, $3 = expected sha
    local url="$1" file="$2" expected="$3"
    if [ -z "$expected" ]; then
        echo "FAIL: no pinned checksum for $file (add it to scripts/ci/tool-checksums.txt)" >&2
        return 1
    fi
    echo "--- $file ---"
    curl -fsSL --retry 3 --retry-all-errors --max-time 300 -o "$WORK/$file" "$url"
    printf '%s  %s\n' "$expected" "$WORK/$file" | sha256sum -c --status - \
        || { echo "FAIL: checksum mismatch for $file" >&2; return 1; }
    echo "checksum OK: $file"
}

want() { # $1 = tool name
    case ",$ONLY," in
        *",$1,"*) return 0 ;;
        *) return 1 ;;
    esac
}

if want shellcheck; then
    SC_VER="${SC_VER:-0.10.0}"
    SC_FILE="shellcheck-v${SC_VER}.linux.x86_64.tar.xz"
    SC_BASE="${SC_BASE:-https://github.com/koalaman/shellcheck/releases/download}"
    SC_SHA="${SC_SHA256:-$(pinned_sha "$SC_FILE")}"
    fetch_verified "$SC_BASE/v$SC_VER/$SC_FILE" "$SC_FILE" "$SC_SHA"
    tar -xf "$WORK/$SC_FILE" -C "$WORK"
    cp "$WORK/shellcheck-v${SC_VER}/shellcheck" "$DEST/"
fi

if want shfmt; then
    SHFMT_VER="${SHFMT_VER:-3.11.0}"
    SHFMT_FILE="shfmt_v${SHFMT_VER}_linux_amd64"
    SHFMT_BASE="${SHFMT_BASE:-https://github.com/mvdan/sh/releases/download}"
    SHFMT_SHA="${SHFMT_SHA256:-$(pinned_sha "$SHFMT_FILE")}"
    fetch_verified "$SHFMT_BASE/v$SHFMT_VER/$SHFMT_FILE" "$SHFMT_FILE" "$SHFMT_SHA"
    cp "$WORK/$SHFMT_FILE" "$DEST/shfmt"
    chmod +x "$DEST/shfmt"
fi

if want actionlint; then
    ACTIONLINT_VER="${ACTIONLINT_VER:-1.7.7}"
    ACTIONLINT_FILE="actionlint_${ACTIONLINT_VER}_linux_amd64.tar.gz"
    ACTIONLINT_BASE="${ACTIONLINT_BASE:-https://github.com/rhysd/actionlint/releases/download}"
    ACTIONLINT_SHA="${ACTIONLINT_SHA256:-$(pinned_sha "$ACTIONLINT_FILE")}"
    fetch_verified "$ACTIONLINT_BASE/v$ACTIONLINT_VER/$ACTIONLINT_FILE" "$ACTIONLINT_FILE" "$ACTIONLINT_SHA"
    tar -xzf "$WORK/$ACTIONLINT_FILE" -C "$DEST" actionlint
fi

if want promtool; then
    PROMTOOL_VER="${PROMTOOL_VER:-3.3.1}"
    PROMTOOL_FILE="prometheus-${PROMTOOL_VER}.linux-amd64.tar.gz"
    PROMTOOL_BASE="${PROMTOOL_BASE:-https://github.com/prometheus/prometheus/releases/download}"
    PROMTOOL_SHA="${PROMTOOL_SHA256:-$(pinned_sha "$PROMTOOL_FILE")}"
    fetch_verified "$PROMTOOL_BASE/v$PROMTOOL_VER/$PROMTOOL_FILE" "$PROMTOOL_FILE" "$PROMTOOL_SHA"
    tar -xzf "$WORK/$PROMTOOL_FILE" -C "$WORK" "prometheus-${PROMTOOL_VER}.linux-amd64/promtool"
    cp "$WORK/prometheus-${PROMTOOL_VER}.linux-amd64/promtool" "$DEST/"
fi

if want gitleaks; then
    GITLEAKS_VER="${GITLEAKS_VER:-8.28.0}"
    GITLEAKS_FILE="gitleaks_${GITLEAKS_VER}_linux_x64.tar.gz"
    GITLEAKS_BASE="${GITLEAKS_BASE:-https://github.com/gitleaks/gitleaks/releases/download}"
    GITLEAKS_SHA="${GITLEAKS_SHA256:-$(pinned_sha "$GITLEAKS_FILE")}"
    fetch_verified "$GITLEAKS_BASE/v$GITLEAKS_VER/$GITLEAKS_FILE" "$GITLEAKS_FILE" "$GITLEAKS_SHA"
    tar -xzf "$WORK/$GITLEAKS_FILE" -C "$DEST" gitleaks
fi

for unknown in ${ONLY//,/ }; do
    case "$unknown" in
        shellcheck|shfmt|actionlint|promtool|gitleaks) ;;
        *) echo "FAIL: unknown tool: $unknown (want one of shellcheck,shfmt,actionlint,promtool,gitleaks)" >&2; exit 2 ;;
    esac
done

echo "=== installed versions ==="
"$DEST/shellcheck" --version 2>/dev/null | head -1 || true
"$DEST/shfmt" --version 2>/dev/null || true
"$DEST/actionlint" --version 2>/dev/null || true
"$DEST/promtool" --version 2>&1 | head -1 || true
"$DEST/gitleaks" version 2>/dev/null || true
echo "=== INSTALL TOOLS GREEN ($DEST) ==="
