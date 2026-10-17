-- Migration 0037: widen the ledger's snapshotted exchange rate.
-- The rate applied to a posting is stored on the CREDIT leg. A cross-currency
-- transfer whose only rate row is the inverse pair (e.g. IDR->USD when only
-- USD->IDR exists) applies the reciprocal of that rate; at DECIMAL(18,6) the
-- reciprocal loses precision and over-credits the target (0.000064 vs
-- 0.000063694268 -> 6.40 instead of 6.37 USD for 100000 IDR). DECIMAL(30,18)
-- keeps the reciprocal exact enough that the credited amount is right at the
-- target currency's own precision, including at scale. Both the live ledger
-- and its immutable archive must widen together so archive/restore keeps the
-- same type.
ALTER TABLE ledger MODIFY COLUMN exchange_rate DECIMAL(30, 18) NULL;
ALTER TABLE ledger_archive MODIFY COLUMN exchange_rate DECIMAL(30, 18) NULL;
