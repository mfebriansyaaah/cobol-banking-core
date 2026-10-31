-- PR-801: Loyalty — extend program registry with domain columns.
-- Keeps legacy OPEN/ACTIVE/CLOSED/DELETED statuses working.

ALTER TABLE loyalty_program
    ADD COLUMN IF NOT EXISTS program_code VARCHAR(40) NULL AFTER loyalty_ref,
    ADD COLUMN IF NOT EXISTS earn_rate DECIMAL(9,4) NOT NULL DEFAULT 0 AFTER program_code,
    ADD COLUMN IF NOT EXISTS burn_rate DECIMAL(9,4) NOT NULL DEFAULT 0 AFTER earn_rate,
    ADD COLUMN IF NOT EXISTS currency CHAR(3) NULL AFTER burn_rate,
    ADD COLUMN IF NOT EXISTS start_date DATE NULL AFTER currency,
    ADD COLUMN IF NOT EXISTS end_date DATE NULL AFTER start_date;

ALTER TABLE loyalty_program
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','CLOSED','DELETED','DRAFT','SUSPENDED') NOT NULL DEFAULT 'OPEN';

CREATE UNIQUE INDEX IF NOT EXISTS uq_loyalty_program_code ON loyalty_program (program_code);
