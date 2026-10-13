# Access-token revocation: token version + per-token denylist

Status: accepted
Date: 2026-10-13
Phase: roadmap item - distributed token denylist.

## Context

Access tokens are stateless. Two revocation shapes are needed:
- revoke **all** tokens for a user (logout, role change); and
- revoke **one** token (a single session/device) without disturbing the others.

The source of truth must be shared by every gateway instance.

## Decision

- **All tokens**: `users.token_version` is embedded in the access token and
  checked on every protected request (`CHECK_TOKEN`). `REVOKE_TOKENS` bumps it.
- **One token**: the access token carries a `jti`; `CHECK_TOKEN` also rejects a
  `jti` present in `revoked_access_tokens` (until it would have expired).
  `REVOKE_ACCESS_TOKEN` inserts the `jti`; `/auth/revoke` does this for the
  presented token. Expired rows are pruned on revoke and on session store.
- **Shared store / seam**: the denylist and version live in the MySQL database,
  which every instance already shares, so revocation is effective across
  instances. The gateway reaches it through a `tokenStore` seam
  (`middleware/src/tokenStore.js`) with `isActive({email, ver, jti})` and
  `revoke({jti, email, ttlSeconds})`; a distributed store (e.g. Redis) can
  implement the same two methods without changing the router.

## Consequences

- Logout revokes the refresh token and bumps the version (all access tokens
  die); `/auth/revoke` denies just one access token.
- Revocation is checked per request (one COBOL call), so it cannot go stale;
  the trade-off is an extra invocation per protected request.
- Multi-region (independent databases) still needs replication or a Redis-backed
  `tokenStore`; the seam is the extension point.
