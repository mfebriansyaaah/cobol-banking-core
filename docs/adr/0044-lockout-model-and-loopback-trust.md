# Lockout-as-DoS model and loopback-only proxy trust

Status: accepted
Date: 2026-10-16
Phase: Rate limiting & abuse audit (FASE D).

## Context

Two residual items closed the campaign:

- The per-account lockout (3 failures -> 15 minutes) lets anyone who knows an
  email keep that account login-blocked — a deliberate trade against password
  guessing whose exact recovery paths were never written down.
- `trust proxy` defaulted to off, so the common same-host-proxy deployment
  collapsed every client into one rate-limit key unless configured.

## Decision

- **Document the lockout-as-DoS model** in `docs/STATUS.md`: the trade is
  accepted (guessing is worse, errors stay masked), lockout never kills live
  sessions and step-up deliberately does not count failures, and recovery is
  ordered — wait out the window, self-service password reset, admin unlock
  (rank-gated, audited).
- **Default trust proxy to `loopback`**: a same-host proxy is trusted, a
  remote `X-Forwarded-For` is ignored (spoof-proof), a directly exposed
  socket keeps its peer IP. `TRUST_PROXY` remains for off-host proxies (hop
  count/subnet, never `true`); the startup warning now fires only on the
  detectable misconfiguration (`true`), since unset is sound.
- Covered by a gateway test proving the loopback trust model (separate keys
  per forged IP, exhaustion per key); session IPs inherit the same correct
  key.

## Consequences

- The most common deployments get correct limiter keys with zero
  configuration, and the lockout trade-off plus its recovery ladder are
  reviewable text instead of tribal knowledge.
- Gateway suite 103 -> 104 (shell 595 unchanged; full run 699 assertions).
