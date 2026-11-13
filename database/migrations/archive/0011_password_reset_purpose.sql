-- Migration 0011: allow PASSWORD_RESET verification codes.
-- The forgot/reset-password flow stores a code against the email with this
-- purpose, alongside the existing SIGNUP and EMAIL_CHANGE codes.
ALTER TABLE verification_logs MODIFY COLUMN purpose ENUM('SIGNUP', 'EMAIL_CHANGE', 'PASSWORD_RESET') NOT NULL;
