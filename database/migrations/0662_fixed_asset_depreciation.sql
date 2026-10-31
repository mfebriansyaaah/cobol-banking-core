-- PR-701: Fixed Asset — depreciation schedule + disposal.

CREATE TABLE IF NOT EXISTS fixed_asset_depreciation (
    depreciation_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    asset_id BIGINT NOT NULL,
    period VARCHAR(20) NOT NULL,
    depreciation_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    accumulated_after DECIMAL(18,4) NOT NULL DEFAULT 0,
    gl_journal_id INT NULL,
    posted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fa_depr_asset FOREIGN KEY (asset_id)
        REFERENCES fixed_asset (id) ON DELETE CASCADE,
    UNIQUE KEY uq_fa_depreciation (asset_id, period),
    INDEX idx_fa_depreciation_asset (asset_id, posted_at),
    CHECK (depreciation_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fixed_asset_disposal (
    disposal_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    asset_id BIGINT NOT NULL,
    disposal_date DATE NOT NULL,
    proceeds_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    gain_loss_amount DECIMAL(18,4) NOT NULL DEFAULT 0,
    reason VARCHAR(255) NULL,
    gl_journal_id INT NULL,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fa_disposal_asset FOREIGN KEY (asset_id)
        REFERENCES fixed_asset (id) ON DELETE CASCADE,
    INDEX idx_fa_disposal_asset (asset_id),
    CHECK (proceeds_amount >= 0)
) ENGINE=InnoDB;
