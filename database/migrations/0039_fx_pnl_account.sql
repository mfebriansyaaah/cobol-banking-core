-- Migration 0039: FX gain/loss account type (D1).
-- Cross-currency transfers round the debit and credit to each currency's
-- own precision; the 4dp residual between the converted value and the
-- posted credit is booked to a bank-owned FX gain/loss account of the
-- target currency (one active FX_PNL account per currency, mirroring
-- FEE_INCOME). Missing or underfunded FX_PNL fails the transfer closed.
ALTER TABLE accounts MODIFY COLUMN account_type
    ENUM('SAVINGS','CHECKING','INVESTMENT','FEE_INCOME','FX_PNL') DEFAULT 'SAVINGS';
