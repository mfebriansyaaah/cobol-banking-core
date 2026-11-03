-- Fixture schema snapshot (mirrors database/schema.sql shape).
CREATE TABLE IF NOT EXISTS users (id INT PRIMARY KEY, email VARCHAR(255));
CREATE TABLE IF NOT EXISTS accounts (id INT PRIMARY KEY, ref VARCHAR(64));
