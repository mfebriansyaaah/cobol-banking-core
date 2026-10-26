#!/usr/bin/env bash
# DB schema tests: migrations applied + D1 tables/columns present.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
if ! db_available; then echo "SKIP: DB unavailable"; exit 0; fi

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

# migration applied
m=$(db_query "SELECT COUNT(*) FROM schema_migrations WHERE version='0108_loan_schedule';")
assert_match "migration 0108 applied" "$m" "^1$"

# tables
for t in loan_schedule loan_installment loan_schedule_audit; do
    c=$(db_query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='$t';")
    assert_match "table $t exists" "$c" "^1$"
done

# key columns
for col in id loan_id term_months interest_rate status version; do
    c=$(db_query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='loan_schedule' AND column_name='$col';")
    assert_match "loan_schedule.$col" "$c" "^1$"
done
for col in id schedule_id seq due_date total_due status paid_amount; do
    c=$(db_query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='loan_installment' AND column_name='$col';")
    assert_match "loan_installment.$col" "$c" "^1$"
done
for col in id schedule_id action actor_email detail; do
    c=$(db_query "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='loan_schedule_audit' AND column_name='$col';")
    assert_match "loan_schedule_audit.$col" "$c" "^1$"
done

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
