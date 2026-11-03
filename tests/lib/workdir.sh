# shellcheck shell=bash
# Throwaway working directories for suites that invoke the COBOL binary
# directly (it reads ./input.txt and writes ./output.txt in the cwd).
# Running in the repo root races parallel suites and litters the checkout.
# Same pattern as the persistent-server path in tests/lib/cobol.sh.
# Usage:
#   . "$ROOT/tests/lib/workdir.sh"
#   WORKDIR="$(make_workdir smoke)" || exit 1
#   trap 'rm -rf "$WORKDIR"' EXIT
#   ( cd "$WORKDIR" && printf 'PING||||||\n' > input.txt && "$ROOT/cobol/bin/main_logic" )
make_workdir() {
    local tag="${1:-run}"
    local dir
    # Tag is a directory name: strip anything that could escape TMPDIR.
    tag="$(printf '%s' "$tag" | tr -cd 'a-zA-Z0-9_-')"
    [ -n "$tag" ] || tag="run"
    dir="$(mktemp -d "${TMPDIR:-/tmp}/cobol-work-${tag}.XXXXXX")" || return 1
    printf '%s' "$dir"
}
