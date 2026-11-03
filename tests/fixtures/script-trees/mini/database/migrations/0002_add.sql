-- Fixture migration 0002: loans table.
CREATE TABLE IF NOT EXISTS loans (
  id INT PRIMARY KEY,
  amount DECIMAL(18,2)
);
