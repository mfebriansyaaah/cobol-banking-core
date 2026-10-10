USE cobol_db;

-- Seed Users
INSERT INTO users (id, email, password_hash, full_name, dob, status, role) VALUES 
(1, 'sender@test.com', 'hash1', 'Sender User', '1990-01-01', 'VERIFIED', 'USER'),
(2, 'receiver@test.com', 'hash2', 'Receiver User', '1990-01-02', 'VERIFIED', 'USER');

-- Seed Currencies (Ensure USD exists as ID 1)
INSERT IGNORE INTO currencies (currency_id, iso_code, symbol, prec_val) VALUES 
(1, 'USD', '$', 2);

-- Seed Accounts
INSERT INTO accounts (account_id, user_id, currency_id, account_type, balance, status) VALUES 
(1, 1, 1, 'SAVINGS', 1000.00, 'ACTIVE'),
(2, 2, 1, 'SAVINGS', 0.00, 'ACTIVE');

-- Seed Initial Ledger entries to maintain integrity
INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description) VALUES 
('INIT_001', 1, 1000.00, 'CREDIT', 1, 'Initial Deposit'),
('INIT_002', 2, 0.00, 'CREDIT', 1, 'Initial Deposit');
