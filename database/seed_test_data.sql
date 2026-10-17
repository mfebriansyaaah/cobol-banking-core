USE cobol_db;

-- Development seed fixtures. Re-runnable: user/account/currency/rate rows
-- are kept when already present (INSERT IGNORE), while the ledger seed rows
-- are reset to exactly the two below (deleted by key, then re-inserted), so
-- balances stay deterministic no matter how often this file is applied.
-- Never run against production data.

-- Seed Users
INSERT IGNORE INTO users (id, email, password_hash, full_name, dob, status, role) VALUES
(1, 'sender@test.com', 'hash1', 'Sender User', '1990-01-01', 'VERIFIED', 'USER'),
(2, 'receiver@test.com', 'hash2', 'Receiver User', '1990-01-02', 'VERIFIED', 'USER'),
(3, 'admin@test.com', 'hash3', 'Admin User', '1990-01-03', 'VERIFIED', 'SUPER_ADMIN');

-- Seed Currencies (Ensure USD exists as ID 1)
INSERT IGNORE INTO currencies (currency_id, iso_code, symbol, prec_val) VALUES 
(1, 'USD', '$', 2);

-- Seed Exchange Rates (base -> target), for cross-currency transfers
INSERT IGNORE INTO exchange_rates (base_currency_id, target_currency_id, exchange_rate) VALUES
(1, 2, 0.92),     -- USD -> EUR
(1, 3, 15700.00), -- USD -> IDR
(1, 4, 0.79);     -- USD -> GBP

-- Seed Accounts
INSERT IGNORE INTO accounts (account_id, user_id, currency_id, account_type, balance, status) VALUES
(1, 1, 1, 'SAVINGS', 1000.00, 'ACTIVE'),
(2, 2, 1, 'SAVINGS', 0.00, 'ACTIVE');

-- Seed Initial Ledger entries to maintain integrity (ledger has no unique
-- key to ignore on, so reset these two rows by key before re-inserting).
DELETE FROM ledger WHERE txn_ref IN ('INIT_001', 'INIT_002');
INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description) VALUES
('INIT_001', 1, 1000.00, 'CREDIT', 1, 'Initial Deposit'),
('INIT_002', 2, 0.00, 'CREDIT', 1, 'Initial Deposit');
