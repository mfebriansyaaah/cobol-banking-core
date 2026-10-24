-- Phase 2 slice: notification audit tracking.

CREATE TABLE IF NOT EXISTS notification_delivery (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    channel VARCHAR(20) NOT NULL,
    recipient VARCHAR(100) NOT NULL,
    status ENUM('PENDING','SENDING','SENT','FAILED','DEAD') NOT NULL DEFAULT 'PENDING',
    retry_count INT NOT NULL DEFAULT 0,
    enqueued_by VARCHAR(100) NOT NULL,
    enqueued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notification_delivery_status (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS notification_delivery_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(40) NOT NULL,
    actor_email VARCHAR(100) NOT NULL,
    entry_id BIGINT NULL,
    detail VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notification_delivery_audit_actor (actor_email, created_at)
) ENGINE=InnoDB;
