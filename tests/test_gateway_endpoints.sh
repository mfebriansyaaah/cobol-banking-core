#!/usr/bin/env bash
# Backward-compatible wrapper. New location: tests/gateway/endpoint_smoke.sh
exec "$(cd "$(dirname "$0")" && pwd)/gateway/endpoint_smoke.sh" "$@"
