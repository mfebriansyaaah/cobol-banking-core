-- Phase 2B slice: phone OTP binding + challenges (PR-082b).
-- phone_links binds a user to a Telegram chat (one row per user); link
-- tokens are single-use with a 10-minute TTL. otp_challenges holds one
-- row per issued code; codes burn after 5 wrong attempts (mirrors the
-- password-reset throttle). Plain codes match the existing
-- verification_logs convention (read by tests, never HTTP-logged).

CREATE TABLE IF NOT EXISTS phone_links (
    user_id INT NOT NULL PRIMARY KEY,
    phone_hash VARCHAR(64) NOT NULL,
    chat_id VARCHAR(64) NULL,
    link_token VARCHAR(64) NULL,
    token_expires_at DATETIME NULL,
    verified_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_phone_chat (chat_id),
    CONSTRAINT fk_phone_links_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS otp_challenges (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    channel ENUM('sms','telegram') NOT NULL DEFAULT 'sms',
    code VARCHAR(10) NOT NULL,
    expires_at DATETIME NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    used TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_otp_user (user_id, created_at),
    CONSTRAINT fk_otp_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE,
    CHECK (attempts >= 0)
) ENGINE=InnoDB;
