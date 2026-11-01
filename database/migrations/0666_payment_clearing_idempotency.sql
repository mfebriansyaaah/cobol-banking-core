-- Payment clearing idempotency: one recorded effect per actor/action/key.
-- The row is inserted in the same transaction as the post/settle update, so a
-- failed operation leaves no key behind and a retry can proceed.

CREATE TABLE IF NOT EXISTS payment_clearing_idempotency (
    actor_email VARCHAR(100) NOT NULL,
    action VARCHAR(20) NOT NULL,
    idem_key VARCHAR(50) NOT NULL,
    clearing_id BIGINT NOT NULL,
    amount DECIMAL(18,4) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (actor_email, action, idem_key),
    INDEX idx_pci_clearing (clearing_id),
    CONSTRAINT fk_pci_clearing FOREIGN KEY (clearing_id)
        REFERENCES payment_clearing(id) ON DELETE CASCADE
) ENGINE=InnoDB;
