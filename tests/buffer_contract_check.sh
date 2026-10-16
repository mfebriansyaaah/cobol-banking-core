#!/bin/bash
# Buffer-contract check: the COBOL side of docs/BUFFER_CONTRACT.md. Every
# field a C function reads or writes must keep at least the size the C bound
# assumes; shrinking one silently reopens a past-the-field write. Fails on
# any mismatch so the regression is caught in review, not in production.
# Usage: ./tests/buffer_contract_check.sh

fail=0

# expect <field> <min-size> <modules...>: every module must declare the field
# with at least <min-size> bytes.
expect() {
    local field="$1" min="$2"; shift 2
    for mod in "$@"; do
        got=$(grep -E "01  $field +PIC X\(([0-9]+)\)" "cobol/src/$mod.cob" | grep -oE 'X\([0-9]+\)' | grep -oE '[0-9]+' | head -1)
        if [ -z "$got" ]; then
            echo "contract: $field not declared in $mod"
            fail=1
        elif [ "$got" -lt "$min" ]; then
            echo "contract: $field is X($got) in $mod, needs at least X($min)"
            fail=1
        fi
    done
}

CORES="auth_core user_core wallet_core"

expect "WS-QUERY" 512 $CORES
expect "WS-RESULT" 16384 $CORES
expect "WS-PREP-SQL" 1024 $CORES

# Every declared bind/param field keeps the size its C bound assumes.
for mod in $CORES; do
    for n in 1 2 3 4 5 6 7; do
        grep -qE "01  WS-BIND-$n +PIC" "cobol/src/$mod.cob" && expect "WS-BIND-$n" 256 "$mod"
    done
    for n in 1 2 3 4 5 6; do
        grep -qE "01  WS-PARAM$n-TRIMMED +PIC" "cobol/src/$mod.cob" && expect "WS-PARAM$n-TRIMMED" 100 "$mod"
    done
done

# Sized fields exist wherever the C function writing them is called.
for mod in $CORES; do
    calls=$(grep -oE '"(hash_password_v2|verify_password|password_needs_rehash|totp_verify|generate_random_code|generate_mfa_secret)"' "cobol/src/$mod.cob" | tr -d '"' | sort -u)
    case " $calls " in
        *"verify_password"*|*"totp_verify"*) expect "WS-VERIFY" 1 "$mod";;
    esac
    case " $calls " in
        *"password_needs_rehash"*) expect "WS-NEEDS-REHASH" 1 "$mod";;
    esac
    case " $calls " in
        *"hash_password_v2"*) expect "WS-HASH" 256 "$mod";;
    esac
    case " $calls " in
        *"verify_password"*) expect "WS-STORED" 256 "$mod";;
    esac
    case " $calls " in
        *"generate_random_code"*)
            grep -q "WS-CODE" "cobol/src/$mod.cob" && expect "WS-CODE" 7 "$mod"
            grep -q "WS-RAND" "cobol/src/$mod.cob" && expect "WS-RAND" 7 "$mod";;
    esac
    case " $calls " in
        *"generate_mfa_secret"*|*"totp_verify"*) expect "WS-MFA-SECRET" 64 "$mod";;
    esac
done

[ "$fail" -eq 0 ] || { echo "BUFFER CONTRACT CHECK FAILED"; exit 1; }
echo "buffer contract check OK"
