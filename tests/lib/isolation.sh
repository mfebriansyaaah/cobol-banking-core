#!/usr/bin/env bash
# Gateway test isolation helpers.
# Each test file should source this and call setup_isolated_schema.

setup_isolated_schema() {
  local prefix="$1"
  local schema="test_${prefix}_$(date +%s%N)"
  echo "$schema"
}

cleanup_isolated_schema() {
  local schema="$1"
  mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
    -u "${DB_MIGRATE_USER:-root}" -p"${DB_MIGRATE_PASS:-root}" \
    -e "DROP DATABASE IF EXISTS $schema;" 2>/dev/null || true
}

# Unique test user generator
unique_test_user() {
  local prefix="$1"
  echo "${prefix}_$(date +%s%N)@test.com"
}