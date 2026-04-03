-- Create table for demo items
CREATE TABLE IF NOT EXISTS items (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Optionally, seed with some data
INSERT INTO items (name, description) VALUES 
  ('Sample Item 1', 'This is a sample item'),
  ('Sample Item 2', 'Another sample item for testing');