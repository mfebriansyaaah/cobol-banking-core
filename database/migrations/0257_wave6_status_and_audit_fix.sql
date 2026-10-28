-- Wave6 modules wrote terminal statuses their tables did not allow, and the
-- loan module wrote audit columns a fresh install did not have. Both defects
-- only show up when the schema is built from this repository in strict mode:
-- the UPDATE is rejected and the COBOL layer reports ERROR|DB_ERROR.
--
-- Existing databases already ran 0197..0226, so the fix has to be a new
-- migration rather than an edit to those files.

-- open banking, PISP, teller and vault close as INACTIVE.
ALTER TABLE open_banking
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','CLOSED','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN';
ALTER TABLE pisp_management
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','CLOSED','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN';
ALTER TABLE teller_management
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','CLOSED','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN';
ALTER TABLE vault_management
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','CLOSED','INACTIVE','DELETED') NOT NULL DEFAULT 'OPEN';

-- consent management revokes rather than closes.
ALTER TABLE consent_management
    MODIFY COLUMN status ENUM('OPEN','ACTIVE','CLOSED','REVOKED','DELETED') NOT NULL DEFAULT 'OPEN';

-- database/schema.sql creates loan_audit before migrations run, so 0147's
-- definition was skipped on a fresh database. The loan module writes both
-- columns on every action, which made every LOAN_* call fail with DB_ERROR.
ALTER TABLE loan_audit ADD COLUMN IF NOT EXISTS old_value VARCHAR(255) NULL;
ALTER TABLE loan_audit ADD COLUMN IF NOT EXISTS new_value VARCHAR(255) NULL;
