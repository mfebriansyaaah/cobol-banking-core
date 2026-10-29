# Runbook — JWT and Refresh Secret Rotation

## Scope

This runbook rotates the gateway signing secrets without invalidating every
live session immediately:

- `JWT_SECRET` — access-token signing key (short-lived).
- `REFRESH_SECRET` — refresh-token signing key (long-lived).
- `JWT_SECRET_PREVIOUS` / `JWT_SECRET_PREVIOUS_UNTIL`
- `REFRESH_SECRET_PREVIOUS` / `REFRESH_SECRET_PREVIOUS_UNTIL`

The implementation lives in `middleware/src/auth.js`. A previous secret is
accepted for verification only while its `*_UNTIL` deadline is in the future.
Signing always uses the current secret.

## Preconditions

- [ ] You have access to the deployment secret store, not a committed `.env`.
- [ ] The new secrets are at least 32 characters and differ from each other.
- [ ] You have a maintenance window and a rollback owner.
- [ ] `NODE_ENV=production` is set; `assertSecureConfig()` refuses development
      defaults, short secrets, and identical access/refresh secrets.
- [ ] You know the refresh-token lifetime. The default refresh lifetime is
      `REFRESH_EXPIRES_IN=7d`; `REFRESH_ABSOLUTE_TTL_DAYS` defaults to 30.

## Variables

| Variable | Meaning |
|---|---|
| `JWT_SECRET` | Current access-token signing secret. |
| `REFRESH_SECRET` | Current refresh-token signing secret. |
| `JWT_SECRET_PREVIOUS` | Old access secret accepted for verification. |
| `JWT_SECRET_PREVIOUS_UNTIL` | Unix epoch seconds when the old access secret stops being accepted. |
| `REFRESH_SECRET_PREVIOUS` | Old refresh secret accepted for verification. |
| `REFRESH_SECRET_PREVIOUS_UNTIL` | Unix epoch seconds when the old refresh secret stops being accepted. |

Set a deadline longer than the longest token you want to keep valid. For
refresh tokens, use at least the refresh lifetime plus a safety margin.

## Procedure

### 1. Generate new secrets

Use the deployment secret store or a CSPRNG. Do not use `openssl rand -base64`
output with `+`, `/`, or `=` if your deployment tool cannot handle them; prefer
hex or a base64url-safe generator.

```sh
openssl rand -hex 32   # JWT_SECRET
openssl rand -hex 32   # REFRESH_SECRET
```

Store both in the secret manager. Never write them to a shell history file or a
committed `.env`.

### 2. Stage the old secrets as previous

Before changing the primary values, set:

```sh
JWT_SECRET_PREVIOUS=<old JWT_SECRET>
JWT_SECRET_PREVIOUS_UNTIL=<epoch seconds>
REFRESH_SECRET_PREVIOUS=<old REFRESH_SECRET>
REFRESH_SECRET_PREVIOUS_UNTIL=<epoch seconds>
```

Compute the deadline:

```sh
date -u -d '+30 days' +%s   # GNU date
```

Deploy this configuration **with the old primary secrets unchanged**. Restart
the gateway and verify that login, refresh, and protected requests still work.
This step only proves the previous-secret fields are accepted.

### 3. Switch the primary secrets

Set the new values:

```sh
JWT_SECRET=<new JWT_SECRET>
REFRESH_SECRET=<new REFRESH_SECRET>
```

Keep the `*_PREVIOUS` values and deadlines from step 2. Deploy and restart all
gateway instances. Tokens minted before the restart verify through the previous
secret; new tokens are signed with the new primary.

### 4. Verify

- [ ] `GET /health` returns 200.
- [ ] A user can log in and receives a new access/refresh token.
- [ ] An existing refresh token still refreshes while `*_PREVIOUS_UNTIL` is in
      the future.
- [ ] A protected request with a newly minted access token succeeds.
- [ ] Logs contain no secret values.
- [ ] Production startup does not report a secret configuration problem.

### 5. Retire the old secrets

After `*_PREVIOUS_UNTIL` has passed:

1. Remove `JWT_SECRET_PREVIOUS`, `JWT_SECRET_PREVIOUS_UNTIL`,
   `REFRESH_SECRET_PREVIOUS`, and `REFRESH_SECRET_PREVIOUS_UNTIL` from the
   secret store.
2. Deploy and restart.
3. Verify login and refresh again.

A previous secret left configured after its deadline is ignored by the code,
but leaving it configured is an unnecessary secret-retention risk.

## Rollback

If the new primary secret is wrong or causes verification failures:

1. Restore the old primary secret as `JWT_SECRET` / `REFRESH_SECRET`.
2. Clear the new values from the secret store.
3. Keep or clear the `*_PREVIOUS` fields depending on which tokens must remain
   valid.
4. Restart and verify login/refresh.

If a secret is suspected compromised, do not rely on the overlap window:
rotate both secrets and revoke active sessions with the admin session-revocation
flow (`REVOKE_ALL_SESSIONS`) or by bumping the user token version.

## Post-rotation checklist

- [ ] New secrets are stored in the secret manager.
- [ ] Old secrets removed after the deadline.
- [ ] No secret appears in logs, tickets, or chat.
- [ ] Rotation date, operator, deadline, and approver recorded in the change
      record.
- [ ] If the rotation changed production behavior, update this runbook.

## References

- `middleware/.env.example` — variable documentation.
- `middleware/src/auth.js` — previous-secret verification and production guard.
- `docs/GOVERNANCE.md` — change and review policy.
