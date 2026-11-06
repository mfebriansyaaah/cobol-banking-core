#!/usr/bin/env bash
# Check email-auth DNS for a domain (PR-089): SPF, DKIM (needs selector),
# DMARC. Advisory only (exit 0 with warnings) unless --strict.
# Usage: scripts/dev/check_email_dns.sh <domain> [dkim-selector] [--strict]
set -u
DOMAIN="${1:-}"
SELECTOR="${2:-mail}"
STRICT=0
[ "${3:-}" = "--strict" ] || [ "${2:-}" = "--strict" ] && STRICT=1
if [ -z "$DOMAIN" ]; then echo "usage: $0 <domain> [dkim-selector] [--strict]" >&2; exit 2; fi
if ! command -v dig >/dev/null 2>&1; then
    echo "SKIP: dig not installed (cannot check DNS)"
    exit 0
fi

WARN=0
check() {
    local name="$1" pattern="$2" label="$3"
    if dig +short TXT "$name" | grep -qi "$pattern"; then
        echo "ok - $label ($name)"
    else
        echo "WARN - $label missing at $name"
        WARN=1
    fi
}

check "$DOMAIN" "v=spf1" "SPF"
check "${SELECTOR}._domainkey.${DOMAIN}" "v=DKIM1" "DKIM (${SELECTOR})"
check "_dmarc.${DOMAIN}" "v=DMARC1" "DMARC"

if [ "$WARN" -eq 1 ] && [ "$STRICT" -eq 1 ]; then exit 1; fi
exit 0
