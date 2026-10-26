#!/usr/bin/env bash
# Backward-compatible wrapper. New location: tests/cobol/table_runner.sh
exec "$(cd "$(dirname "$0")" && pwd)/cobol/table_runner.sh" "$@"
