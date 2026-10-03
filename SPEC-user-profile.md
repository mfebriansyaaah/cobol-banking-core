# Spec: user-profile

## Objective
Implement the user profile management system. This module provides a read-only dashboard for users to see their essential account info and a strict, two-step verification process for updating their email address to prevent account hijacking.

## Tech Stack
- **Language:** GnuCOBOL (with `cob-odbc`)
- **Database:** MySQL 8.0
- **Interface:** Node.js Express (via CLI Call)

## Commands
- **Build:** `cobc -x -o cobol/bin/user_profile.exe cobol/src/user_profile.cob -lodbc32`
- **Test:** `cobol/bin/user_profile.exe GET_DASHBOARD 101`
- **Dev:** `npm run dev` (via middleware)

## Project Structure
- `cobol/src/user_profile.cob` $\rightarrow$ Profile and email update logic
- `cobol/bin/user_profile.exe` $\rightarrow$ Compiled binary
- `database/schema.sql` $\rightarrow$ User table definition

## Code Style
- **Consistency:** Strict separation between read-only actions (Dashboard) and write actions (Email Update).
- **Output:** Pipe-delimited strings (`|`) to `stdout`.
- **Validation:** All email updates must be preceded by a successful verification code check.
- **Example Output:** `SUCCESS|DASHBOARD|150000|user@email.com|Budi Santoso`

## Testing Strategy
- **Unauthorized Access Test:** Attempt to access the dashboard of another user by manipulating `user_id`.
- **Verification Flow Test:** Ensure email cannot be updated without a valid 6-digit code.
- **Invalid Code Test:** Verify that incorrect codes return Exit Code 1 (Not Found/Invalid).

## Boundaries
- **Always:** Validate the user's current session/ID before allowing any profile change.
- **Ask first:** Adding more editable fields to the user profile.
- **Never:** Allow the user to change their `user_id` or `dob` (Date of Birth) once registered.

## Success Criteria
- [ ] `GET_DASHBOARD` returns exactly: `balance`, `email`, and `full_name`.
- [ ] `REQ_EMAIL_CHANGE` generates a 6-digit code and stores it in the DB for the specific user.
- [ ] `CONFIRM_EMAIL_CHANGE` only updates the email if the provided code matches the one in the DB.
- [ ] User cannot change their email to one that is already registered by another user.

## Open Questions
- Should we implement an expiration time for the email change verification code (e.g., valid for only 15 minutes)?
