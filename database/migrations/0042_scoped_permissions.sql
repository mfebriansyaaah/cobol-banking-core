-- Migration 0042: scoped permission catalog (ADR 0074).
-- Almost every sensitive gate is a hardcoded `role = 'SUPER_ADMIN'` check,
-- so one rank holds every unrelated power. The catalog names each
-- capability and role_permissions maps roles to what they hold; phase 1
-- reproduces exactly the current behavior (SUPER_ADMIN holds everything,
-- other roles hold none of the new permissions), so the refactor changes
-- the mechanism without changing who may do what.
--
-- A permission set (for example a read-only auditor shape) is carried as
-- data on purpose: widening the users.role ENUM is the documented
-- non-replayable migration exception, while granting data needs no
-- migration at all. Any grant to a non-SUPER_ADMIN role is a Gate 0 owner
-- decision and is not made here.
CREATE TABLE IF NOT EXISTS permissions (
    name VARCHAR(30) NOT NULL PRIMARY KEY,
    description VARCHAR(255) NOT NULL DEFAULT ''
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS role_permissions (
    role ENUM('USER','MANAGER','SUPER_ADMIN') NOT NULL,
    permission VARCHAR(30) NOT NULL,
    PRIMARY KEY (role, permission),
    CONSTRAINT fk_role_perm_perm FOREIGN KEY (permission)
        REFERENCES permissions(name) ON DELETE CASCADE
) ENGINE=InnoDB;

INSERT IGNORE INTO permissions (name, description) VALUES
    ('AUDIT_READ', 'Read the audit trail and the metrics endpoint'),
    ('AUDIT_ARCHIVE', 'Archive audit rows past the retention window'),
    ('RECONCILE_READ', 'Read reconciliation runs and exception findings'),
    ('RECONCILE_RUN', 'Record a reconciliation run');

INSERT IGNORE INTO role_permissions (role, permission) VALUES
    ('SUPER_ADMIN', 'AUDIT_READ'),
    ('SUPER_ADMIN', 'AUDIT_ARCHIVE'),
    ('SUPER_ADMIN', 'RECONCILE_READ'),
    ('SUPER_ADMIN', 'RECONCILE_RUN');
