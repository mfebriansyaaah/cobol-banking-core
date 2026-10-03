# Spec: wallet-core

## Objective
Implement the financial core of the e-wallet. This module is responsible for managing user balances and ensuring that every single cent moving in or out of an account is recorded in an immutable ledger. The primary goal is absolute data integrity (Atomic Transactions).

## Tech Stack
- **Language:** GnuCOBOL (with `cob-odbc`)
- **Database:** MySQL 8.0 (utilizing ACID transactions)
- **Interface:** Node.js Express (via CLI Call)

## Commands
- **Build:** `cobc -x -o cobol/bin/wallet_core.exe cobol/src/wallet_core.cob -lodbc32`
- **Test:** `cobol/bin/wallet_core.exe TRANSFER 101 102 "50000"`
- **Dev:** `npm run dev` (via middleware)

## Project Structure
- `cobol/src/wallet_core.cob` $\rightarrow$ Transaction and balance logic
- `cobol/bin/wallet_core.exe` $\rightarrow$ Compiled binary
- `database/schema.sql` $\rightarrow$ Ledger and Balance table definitions

## Code Style
- **Consistency:** Use `BEGIN TRANSACTION`, `COMMIT`, and `ROLLBACK` explicitly for all fund movements.
- **Output:** Pipe-delimited strings (`|`) to `stdout`.
- **Precision:** Use `PIC 9(12)V99` for all financial amounts to avoid floating point errors.
- **Example Output:** `SUCCESS|TRANSFER_COMPLETE|TXN12345|NEW_BAL:150000`

## Testing Strategy
- **Concurrency Test:** Simulate two simultaneous transfers from the same account to check for double-spending (Row Locking).
- **Failure Test:** Force a database crash/disconnect during a transfer to verify that `ROLLBACK` prevents balance loss.
- **Integration Test:** Node.js $\rightarrow$ Wallet Core $\rightarrow$ MySQL $\rightarrow$ Ledger check.

## Boundaries
- **Always:** Create a ledger entry before updating the balance. Use `FOR UPDATE` in SQL to lock rows during transactions.
- **Ask first:** Changing the currency precision or adding new transaction types.
- **Never:** Update the `balance` column without a corresponding `ledger` entry. Never allow a balance to go negative unless explicitly required.

## Success Criteria
- [ ] Transfer logic is atomic: Either both accounts are updated and ledger is written, or nothing happens.
- [ ] Balance in the `users` table always matches the sum of the `ledger` entries for that user.
- [ ] Double-spending is impossible due to row-level locking.
- [ ] All financial errors return Exit Code 2 (DB Error) or 4 (Invalid Arg).

## Open Questions
- Should we implement a "Maximum Transfer Limit" per transaction at the COBOL level?
