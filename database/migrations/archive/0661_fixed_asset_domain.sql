-- PR-701: Fixed Asset — extend registry + audit detail.
-- Keeps legacy OPEN/ACTIVE/DISPOSED/DELETED statuses working.

ALTER TABLE fixed_asset
    ADD COLUMN IF NOT EXISTS asset_category VARCHAR(30) NOT NULL DEFAULT 'OTHER' AFTER asset_name,
    ADD COLUMN IF NOT EXISTS acquisition_date DATE NULL AFTER asset_category,
    ADD COLUMN IF NOT EXISTS residual_value DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER acquisition_cost,
    ADD COLUMN IF NOT EXISTS useful_life_months INT NOT NULL DEFAULT 0 AFTER residual_value,
    ADD COLUMN IF NOT EXISTS depreciation_method ENUM('STRAIGHT_LINE','DECLINING') NOT NULL DEFAULT 'STRAIGHT_LINE' AFTER useful_life_months,
    ADD COLUMN IF NOT EXISTS net_book_value DECIMAL(18,4) NOT NULL DEFAULT 0 AFTER accumulated_depreciation,
    ADD COLUMN IF NOT EXISTS cost_center VARCHAR(40) NULL AFTER net_book_value,
    ADD COLUMN IF NOT EXISTS gl_asset_account VARCHAR(20) NULL AFTER cost_center,
    ADD COLUMN IF NOT EXISTS gl_depreciation_account VARCHAR(20) NULL AFTER gl_asset_account,
    ADD COLUMN IF NOT EXISTS gl_gain_loss_account VARCHAR(20) NULL AFTER gl_depreciation_account;

ALTER TABLE fixed_asset
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','DISPOSED','DELETED','IMPAIRED') NOT NULL DEFAULT 'OPEN';

CREATE INDEX IF NOT EXISTS idx_fixed_asset_category ON fixed_asset (asset_category, status);

ALTER TABLE fixed_asset_audit
    ADD COLUMN IF NOT EXISTS old_value VARCHAR(255) NULL AFTER detail,
    ADD COLUMN IF NOT EXISTS new_value VARCHAR(255) NULL AFTER old_value;
