-- Phase 2B slice: KYC identity foundation (PR-085 batch commit 1).
-- Reshapes the week-old 082b phone tables to the plan spec (hashed codes,
-- purpose/status machine, surrogate link keys) and adds the KYC core:
-- users identity columns, identity_verifications, manual_reviews,
-- consent_records. DROP+CREATE is safe: the 082b tables hold test data
-- only and nothing else builds on them yet.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS phone_e164 VARCHAR(20) NULL,
  ADD COLUMN IF NOT EXISTS phone_verified_at DATETIME NULL,
  ADD COLUMN IF NOT EXISTS nik_hash CHAR(64) NULL,
  ADD COLUMN IF NOT EXISTS nik_last4 CHAR(4) NULL,
  ADD COLUMN IF NOT EXISTS kyc_status ENUM('UNVERIFIED','PENDING','NIK_VALID','CONTACT_VERIFIED','MANUAL_REVIEW','APPROVED','REJECTED') DEFAULT 'UNVERIFIED',
  ADD COLUMN IF NOT EXISTS kyc_verified_at DATETIME NULL;

CREATE TABLE IF NOT EXISTS identity_verifications (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  provider VARCHAR(32) NOT NULL,
  method ENUM('NIK_STRUCTURAL','NIK_REMOTE','KTP_OCR','MANUAL') NOT NULL,
  status ENUM('PENDING','VALID','INVALID','MANUAL_REVIEW','ERROR') NOT NULL,
  result_code VARCHAR(64) NULL,
  provider_ref VARCHAR(128) NULL,
  score DECIMAL(5,2) NULL,
  attempts INT NOT NULL DEFAULT 0,
  expires_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_idv_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_idv_user_status (user_id, status, created_at)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS otp_challenges;
CREATE TABLE otp_challenges (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  channel ENUM('EMAIL','PHONE') NOT NULL,
  destination_hash CHAR(64) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  purpose VARCHAR(32) NOT NULL,
  status ENUM('PENDING','VERIFIED','EXPIRED','LOCKED') NOT NULL DEFAULT 'PENDING',
  attempts INT NOT NULL DEFAULT 0,
  provider VARCHAR(32) NULL,
  provider_ref VARCHAR(128) NULL,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_otp_lookup (destination_hash, purpose, status, expires_at),
  INDEX idx_otp_user (user_id, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS manual_reviews (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  kind ENUM('KYC','SCREENING') NOT NULL,
  ref_id BIGINT NULL,
  status ENUM('OPEN','APPROVED','REJECTED') NOT NULL DEFAULT 'OPEN',
  reviewer_email VARCHAR(100) NULL,
  reason VARCHAR(255) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  reviewed_at DATETIME NULL,
  CONSTRAINT fk_review_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_review_status (status, kind, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS consent_records (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  purpose VARCHAR(64) NOT NULL,
  version VARCHAR(20) NOT NULL,
  granted_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  CONSTRAINT fk_consent_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_consent_user (user_id, purpose)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS phone_links;
-- Superset of the plan shape: link_token/token_expires_at carry the
-- Telegram deep-link binding flow (PR-082 step 2); verified_at records
-- OTP proof; chat_id NULLABLE because the link row is created at BEGIN
-- time, before any chat exists. Without these the plan's own binding
-- flow has nowhere to live.
CREATE TABLE phone_links (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  chat_id VARCHAR(64) NULL,
  phone_hash CHAR(64) NOT NULL,
  linked_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  link_token VARCHAR(64) NULL,
  token_expires_at DATETIME NULL,
  verified_at DATETIME NULL,
  UNIQUE KEY uq_phone_link_user (user_id),
  UNIQUE KEY uq_phone_link_chat (chat_id),
  CONSTRAINT fk_phone_link_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
