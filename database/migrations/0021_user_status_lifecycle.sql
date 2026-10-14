-- Migration 0021: user account lifecycle states.
-- SUSPENDED (disabled by an admin) and CLOSED (deactivated by the owner or an
-- admin) join UNVERIFIED/VERIFIED; login honours them.
ALTER TABLE users
    MODIFY COLUMN status ENUM('UNVERIFIED', 'VERIFIED', 'SUSPENDED', 'CLOSED') DEFAULT 'UNVERIFIED';
