# Spec: auth-identity

## Objective
Implement a strict identity and authentication system where COBOL handles the business logic of registration, email verification, and secure login, ensuring no unverified user can access the system.

## Tech Stack
- **Language:** GnuCOBOL (with `cob-odbc`)
- **Database:** MySQL 8.0
- **Security:** External C-Library for Password Hashing (Bcrypt/Argon2)
- **Interface:** Node.js Express (via CLI Call)

## Commands
- **Build:** `cobc -x -O3 -o cobol/bin/auth_identity.exe cobol/src/auth_identity.cob cobol/c_lib/hash_lib.c -lodbc32`
- **Test:** `cobol/bin/auth_identity.exe REQUEST_SIGNUP "email|pass|name|dob"`
- **Dev:** `npm run dev` (via middleware)

## Project Structure
- `cobol/src/auth_identity.cob` $\rightarrow$ Core authentication logic
- `cobol/bin/auth_identity.exe` $\rightarrow$ Compiled binary
- `cobol/config/odbc.ini` $\rightarrow$ DSN for MySQL connection

## Code Style
- **Naming:** CamelCase for variables, UPPER_SNAKE_CASE for constants/actions.
- **Output:** Pipe-delimited strings (`|`) to `stdout`.
- **Status:** Return specific Exit Codes for error handling.
- **Example Output:** `SUCCESS|USER_CREATED|101` or `ERROR|INVALID_CODE|Code is incorrect`

## Testing Strategy
- **Unit Tests:** Manual CLI calls to the binary with various inputs (valid/invalid email, wrong code).
- **Integration Tests:** Node.js API calls $\rightarrow$ COBOL $\rightarrow$ MySQL.
- **Security Tests:** Attempting to login with `UNVERIFIED` status.

## Boundaries
- **Always:** Hash passwords before storing, validate email uniqueness, use SQL Transactions.
- **Ask first:** Changing the hashing algorithm or adding new user fields.
- **Never:** Store passwords in plain text, allow login for unverified accounts.

## Success Criteria
- [x] `REQUEST_SIGNUP` creates a user with `status = 'UNVERIFIED'`, generates a 6-digit secure code, and records it in `verification_logs` with a 24-hour expiry.
- [x] `VERIFY_EMAIL` updates status to `VERIFIED` only if the code matches, is not yet used, and has not expired.
- [x] `CHECK_ROLE` validates user roles using normalized `role_assignments` and `roles` tables.
- [x] `CHANGE_ROLE` allows `SUPER_ADMIN` to modify user roles with strict validation.
- [ ] `AUTH_LOGIN` returns a success code only if the user is `VERIFIED` and the password hash matches.
- [ ] All errors return the correct Exit Code (1 for Not Found, 2 for DB Error, 4 for Invalid Arg).

## Open Questions
- Which specific C-library for hashing is available on the target production server?
