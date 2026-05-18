CREATE TABLE test_table(id int);

UPDATE users SET name='x';  -- ⚠️ should trigger unsafe update rule

DELETE FROM users;          -- ⚠️ should trigger unsafe delete rule

TRUNCATE TABLE users;       -- ⚠️ should be blocked
