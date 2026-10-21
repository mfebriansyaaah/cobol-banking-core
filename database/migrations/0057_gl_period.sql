-- Phase 1 Sprint 1: GL period control.
-- A period is YYYY-MM. Journals post only into an OPEN period.
CREATE TABLE IF NOT EXISTS gl_period (
    period_code CHAR(7) PRIMARY KEY,
    status ENUM('OPEN','CLOSED') NOT NULL DEFAULT 'OPEN',
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at DATETIME NULL,
    closed_by VARCHAR(100),
    CHECK (period_code REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$')
) ENGINE=InnoDB;

INSERT IGNORE INTO gl_period (period_code, status)
VALUES (DATE_FORMAT(CURDATE(), '%Y-%m'), 'OPEN');
