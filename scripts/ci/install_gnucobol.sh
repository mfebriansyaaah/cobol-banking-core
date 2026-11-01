#!/usr/bin/env bash
# Install a coverage-capable GnuCOBOL toolchain for the coverage jobs.
#
# Ubuntu 24.04's apt gnucobol (3.1.2) does not know `cobc --coverage`, which
# the curated-core measurement needs. GnuCOBOL 3.2 added gcov support, so the
# coverage jobs build it from the official tarball instead of apt.
#
# Usage: scripts/ci/install_gnucobol.sh [VERSION] [PREFIX]
#   VERSION defaults to 3.2, PREFIX to $HOME/.local/gnucobol.
#   Pinned SHA-256 per version below; a version without a pinned hash refuses
#   to download (supply EXPECTED_SHA256 explicitly to bump).
#
# Idempotent: exits 0 immediately when $PREFIX/bin/cobc already reports the
# requested version. CI caches $HOME/.local/gnucobol between runs, so the
# ~5 minute build happens once.
#
# After installing, expose the toolchain (the build itself must not guess the
# CI environment, so it only prints the snippet):
#
#   echo "$HOME/.local/gnucobol/bin" >> "$GITHUB_PATH"
#   echo "LD_LIBRARY_PATH=$HOME/.local/gnucobol/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" >> "$GITHUB_ENV"
set -euo pipefail

VERSION="${1:-3.2}"
PREFIX="${2:-$HOME/.local/gnucobol}"

pinned_sha() {
    case "$1" in
        3.2) printf '%s' '3bb48af46ced4779facf41fdc2ee60e4ccb86eaa99d010b36685315df39c2ee2' ;;
        *) printf '' ;;
    esac
}

EXPECTED="${EXPECTED_SHA256:-$(pinned_sha "$VERSION")}"
if [ -z "$EXPECTED" ]; then
    echo "FAIL: no pinned SHA-256 for GnuCOBOL $VERSION; set EXPECTED_SHA256 explicitly" >&2
    exit 2
fi

if [ -x "$PREFIX/bin/cobc" ] && [ "$("$PREFIX/bin/cobc" --version 2>/dev/null | grep -c "$VERSION")" -gt 0 ]; then
    echo "GnuCOBOL $VERSION already installed at $PREFIX"
    exit 0
fi

URL="https://ftp.gnu.org/gnu/gnucobol/gnucobol-$VERSION.tar.xz"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/gnucobol-install.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "=== downloading GnuCOBOL $VERSION ==="
curl -sSL --retry 3 --retry-all-errors --max-time 300 -o "$WORK/gnucobol.tar.xz" "$URL"

echo "=== verifying checksum ==="
actual="$(sha256sum "$WORK/gnucobol.tar.xz" | awk '{print $1}')"
if [ "$actual" != "$EXPECTED" ]; then
    echo "FAIL: checksum mismatch for $URL" >&2
    echo "  expected: $EXPECTED" >&2
    echo "  actual:   $actual" >&2
    exit 1
fi

echo "=== building (this takes a few minutes) ==="
tar -xf "$WORK/gnucobol.tar.xz" -C "$WORK"
cd "$WORK"/gnucobol-*
# Modern GCC (14+) promotes old-C idioms to hard errors and defaults to a
# newer C standard where K&R-style `int (*)()` prototypes reject arguments;
# GnuCOBOL 3.2 predates both. Downgrade the new warnings and pin C17
# semantics: the code is unchanged upstream and builds clean on the GCC
# versions CI ships.
export CFLAGS="${CFLAGS:--O2} -std=gnu17 -Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=return-mismatch"
./configure --prefix="$PREFIX" --without-db --without-curses >/tmp/gnucobol-configure.log 2>&1 || {
    tail -30 /tmp/gnucobol-configure.log >&2
    exit 1
}
make -j"$(nproc)" >/tmp/gnucobol-make.log 2>&1 || {
    tail -30 /tmp/gnucobol-make.log >&2
    exit 1
}
make install >/tmp/gnucobol-install.log 2>&1 || {
    tail -30 /tmp/gnucobol-install.log >&2
    exit 1
}

echo "=== verifying ==="
"$PREFIX/bin/cobc" --version | head -n 1
# NOTE: grep -c (not -q) below: -q closes the pipe on first match, the large
# --help output then kills cobc with SIGPIPE, and with `set -o pipefail` the
# 141 status would fail the check even though the flag exists.
if [ "$("$PREFIX/bin/cobc" --help 2>&1 | grep -c -- '--coverage')" -eq 0 ]; then
    echo "FAIL: installed cobc has no --coverage support" >&2
    exit 1
fi
echo "GnuCOBOL $VERSION ready at $PREFIX (with --coverage support)"
echo 'expose with:'
echo '  echo "$HOME/.local/gnucobol/bin" >> "$GITHUB_PATH"'
echo '  echo "LD_LIBRARY_PATH=$HOME/.local/gnucobol/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" >> "$GITHUB_ENV"'
