-- Migration 0008: exchange rates for cross-currency transfers.
-- Re-introduces exchange_rates (dropped in 0007) now that the FX feature
-- exists, and seeds the development rates. Rates are base -> target.
CREATE TABLE IF NOT EXISTS exchange_rates (
    rate_id INT AUTO_INCREMENT PRIMARY KEY,
    base_currency_id INT NOT NULL,
    target_currency_id INT NOT NULL,
    exchange_rate DECIMAL(18,6) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_base_curr FOREIGN KEY (base_currency_id) REFERENCES currencies(currency_id),
    CONSTRAINT fk_target_curr FOREIGN KEY (target_currency_id) REFERENCES currencies(currency_id),
    UNIQUE KEY unique_pair (base_currency_id, target_currency_id)
) ENGINE=InnoDB;

INSERT IGNORE INTO exchange_rates (base_currency_id, target_currency_id, exchange_rate) VALUES
(1, 2, 0.92),     -- USD -> EUR
(1, 3, 15700.00), -- USD -> IDR
(1, 4, 0.79);     -- USD -> GBP
