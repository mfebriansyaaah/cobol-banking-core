-- Fixture migration 0001: accounts table.
CREATE TABLE IF NOT EXISTS accounts (
  id INT PRIMARY KEY,
  ref VARCHAR(64)
);
