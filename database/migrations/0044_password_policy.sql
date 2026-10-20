-- Migration 0044: password policy hardening (ADR 0077).
-- password_history keeps the hashes of the last N passwords a user set, so a
-- change or reset cannot silently restore a recently used credential.
-- password_blocklist is an owner-controlled deny list of common passwords,
-- keyed by the SHA-256 hex of the lowercased value (case-insensitive match).
-- The seed below is a small development placeholder; the production list is
-- supplied as data by the accountable owner, not hardcoded here.
CREATE TABLE IF NOT EXISTS password_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_password_history_user (user_id, created_at),
    CONSTRAINT fk_password_history_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS password_blocklist (
    hash CHAR(64) NOT NULL PRIMARY KEY,
    note VARCHAR(100) NOT NULL DEFAULT ''
) ENGINE=InnoDB;

INSERT IGNORE INTO password_blocklist (hash, note) VALUES
    ('5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', 'password'),
    ('0b14d501a594442a01c6859541bcb3e8164d183d32937b851835442f69d5c94e', 'password1'),
    ('b3d17ebbe4f2b75d27b6309cfaae1487b667301a73951e7d523a039cd2dfe110', 'password12'),
    ('ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f', '12345678'),
    ('15e2b0d3c33891ebb0f1ef609ec419420c20e320ce94c65fbc8c3312448eb225', '123456789'),
    ('daaad6e5604e8e17bd9f108d91e26afe6281dac8fda0091040a7a6d7bd9b43b5', 'qwerty123'),
    ('1c8bfe8f801d79745c4631d09fff36c82aa37fc4cce4fc946683d7b336b63032', 'letmein'),
    ('e4ad93ca07acb8d908a3aa41e920ea4f4ef4f26e7f86cf8291c5db289780a5ae', 'iloveyou'),
    ('240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'admin123'),
    ('fcc3a23fc7232cc89c7cb0f23d8774fefb73d7dc2ab22e6a1b6b8b202b4dcc91', 'welcome1'),
    ('8f0e2f76e22b43e2855189877e7dc1e1e7d98c226c95db247cd1d547928334a9', 'passw0rd'),
    ('14f8f4bb8c0e79a02670a5fea5682da717a5b3d3dc7b1706f7a4bab9afae18c2', 'abc12345'),
    ('ee79976c9380d5e337fc1c095ece8c8f22f91f306ceeb161fa51fecede2c4ba1', '11111111'),
    ('6382deaf1f5dc6e792b76db4a4a7bf2ba468884e000b25e7928e621e27fb23cb', 'football'),
    ('e48443929f57ec4cb965d358a825849155b2828873c4ed2929fd711bc9f01347', 'monkey123');
