-- Phase 1 Sprint 1 slice 6: notification templates/preferences.

CREATE TABLE IF NOT EXISTS notification_template (
    template_code VARCHAR(40) PRIMARY KEY,
    purpose VARCHAR(32) NOT NULL,
    channel ENUM('EMAIL','INAPP') NOT NULL DEFAULT 'EMAIL',
    subject VARCHAR(160) NOT NULL,
    body VARCHAR(1000) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_notification_template_purpose (purpose, channel, enabled)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notification_preference (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_email VARCHAR(100) NOT NULL,
    purpose VARCHAR(32) NOT NULL,
    channel ENUM('EMAIL','INAPP') NOT NULL DEFAULT 'EMAIL',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_notification_preference (user_email, purpose, channel),
    INDEX idx_notification_preference_user (user_email, enabled)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notification_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    template_code VARCHAR(40) NULL,
    user_email VARCHAR(100) NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notification_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
