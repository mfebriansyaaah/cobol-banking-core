-- Migration 0016: one-time transfer reversal register.
-- A row per reversed transfer (primary key on the original reference) makes a
-- reversal idempotent and lets the status endpoint report REVERSED.
CREATE TABLE IF NOT EXISTS transfer_reversals (
    orig_ref VARCHAR(50) PRIMARY KEY,
    actor_id INT NOT NULL,
    reversed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reversal_actor FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
