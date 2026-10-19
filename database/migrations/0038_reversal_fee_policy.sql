-- Migration 0038: owner-controlled fee-refund policy for reversals (D2).
-- A reversal carries a reason; this policy table decides whether the fee
-- posted by the original transfer is refunded to the sender. Seeded
-- BANK_ERROR (refund) and CUSTOMER_ERROR (retain); the core fails closed
-- on unknown reasons. The reason is recorded on the reversal marker.
CREATE TABLE IF NOT EXISTS reversal_fee_policy (
    reason VARCHAR(100) PRIMARY KEY,
    refund_fee TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
INSERT IGNORE INTO reversal_fee_policy (reason, refund_fee) VALUES
('BANK_ERROR', 1),
('CUSTOMER_ERROR', 0);
ALTER TABLE transfer_reversals ADD COLUMN IF NOT EXISTS reason VARCHAR(100) NULL;
