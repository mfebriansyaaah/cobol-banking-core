# JSON body cap and trust-proxy warning

Status: accepted
Date: 2026-10-16
Phase: Rate limiting & abuse audit (FASE A).

## Context

Two foundational gaps sat underneath every rate limiter:

- `express.json()` ran unbounded (100kb default) while legitimate bodies are
  under a kilobyte — an oversized body cost parsing memory before the 500-byte
  input-line cap or any route logic could reject it.
- The limiter key is `req.ip`, which follows `TRUST_PROXY`. Unset behind a
  proxy, every client shares one key (the limiter collapses into self-DoS);
  set to `true`, any caller spoofs `X-Forwarded-For` and gets a fresh key per
  request (the limiter is bypassed entirely). Neither failure warned.

## Decision

- Cap JSON bodies at `JSON_BODY_LIMIT` (default 20kb, ~20x headroom over any
  legitimate request) via `express.json({ limit })`; overflow maps to a
  uniform 413 `BODY_TOO_LARGE` (gateway-local, like `RATE_LIMITED`) before the
  request reaches the router or COBOL.
- Add a pure `trustProxyWarning()` helper (null when sound, message when the
  setting is unset or `true`) with unit tests, and log it as a production
  startup warning (`trust_proxy_warning`), mirroring the mailer warnings.
- Document the hop-count rule and the body cap in `middleware/.env.example`.

## Consequences

- Parsing-memory amplification is bounded, and a wrong proxy setup is visible
  in startup logs instead of silently defeating every limiter.
- Gateway suite 99 -> 101 (shell 584 unchanged; full run 685 assertions).
- Deliberately unchanged: malformed JSON still maps to 500 (pre-existing
  behaviour, no leak); per-account throttles and fail-open observability are
  later phases of this campaign.
