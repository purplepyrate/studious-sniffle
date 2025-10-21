-- Sample Data for Finance App Database
-- This file provides example data to test the schema

BEGIN;

-- Insert sample categories
INSERT INTO categories (id, name, description, color, icon, is_income) VALUES
    (uuid_generate_v4(), 'Salary', 'Regular employment income', '#4CAF50', 'work', true),
    (uuid_generate_v4(), 'Freelance', 'Freelance and contract work', '#8BC34A', 'freelance', true),
    (uuid_generate_v4(), 'Investment', 'Returns from investments', '#2196F3', 'trending_up', true),
    (uuid_generate_v4(), 'Groceries', 'Food and household items', '#FF9800', 'shopping_cart', false),
    (uuid_generate_v4(), 'Restaurants', 'Dining out and food delivery', '#F44336', 'restaurant', false),
    (uuid_generate_v4(), 'Transportation', 'Gas, public transport, rideshare', '#9C27B0', 'directions_car', false),
    (uuid_generate_v4(), 'Entertainment', 'Movies, games, subscriptions', '#E91E63', 'movie', false),
    (uuid_generate_v4(), 'Utilities', 'Electricity, water, internet, phone', '#607D8B', 'build', false),
    (uuid_generate_v4(), 'Healthcare', 'Medical expenses and insurance', '#00BCD4', 'local_hospital', false),
    (uuid_generate_v4(), 'Education', 'Books, courses, training', '#3F51B5', 'school', false);

-- Insert sample users
INSERT INTO users (id, email, username, first_name, last_name) VALUES
    ('11111111-1111-1111-1111-111111111111', 'john.doe@example.com', 'johndoe', 'John', 'Doe'),
    ('22222222-2222-2222-2222-222222222222', 'jane.smith@example.com', 'janesmith', 'Jane', 'Smith');

-- Insert sample accounts
INSERT INTO accounts (id, user_id, name, account_type, balance) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Main Checking', 'checking', 5420.75),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'Savings Account', 'savings', 15000.00),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'Credit Card', 'credit_card', -1250.30),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'Primary Checking', 'checking', 3200.15);

-- Sample transactions across different time periods for testing time-based queries
INSERT INTO transactions (user_id, account_id, category_id, amount, description, transaction_date, tags) 
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (SELECT id FROM categories WHERE name = 'Salary' LIMIT 1),
    3500.00,
    'Monthly salary deposit',
    CURRENT_DATE - INTERVAL '0 days',
    ARRAY['salary', 'regular']
UNION ALL
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (SELECT id FROM categories WHERE name = 'Groceries' LIMIT 1),
    -89.43,
    'Weekly grocery shopping',
    CURRENT_DATE - INTERVAL '2 days',
    ARRAY['food', 'weekly']
UNION ALL
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (SELECT id FROM categories WHERE name = 'Transportation' LIMIT 1),
    -45.20,
    'Gas station fill-up',
    CURRENT_DATE - INTERVAL '3 days',
    ARRAY['gas', 'car']
UNION ALL
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (SELECT id FROM categories WHERE name = 'Restaurants' LIMIT 1),
    -32.75,
    'Dinner at Italian restaurant',
    CURRENT_DATE - INTERVAL '5 days',
    ARRAY['dining', 'date_night']
UNION ALL
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (SELECT id FROM categories WHERE name = 'Utilities' LIMIT 1),
    -125.80,
    'Monthly electricity bill',
    CURRENT_DATE - INTERVAL '15 days',
    ARRAY['bills', 'monthly']
UNION ALL
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (SELECT id FROM categories WHERE name = 'Freelance' LIMIT 1),
    750.00,
    'Website development project',
    CURRENT_DATE - INTERVAL '20 days',
    ARRAY['freelance', 'web_dev']
UNION ALL
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (SELECT id FROM categories WHERE name = 'Entertainment' LIMIT 1),
    -15.99,
    'Netflix monthly subscription',
    CURRENT_DATE - INTERVAL '25 days',
    ARRAY['subscription', 'streaming']
UNION ALL
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (SELECT id FROM categories WHERE name = 'Salary' LIMIT 1),
    3500.00,
    'Monthly salary deposit',
    CURRENT_DATE - INTERVAL '32 days',
    ARRAY['salary', 'regular'];

-- Add some older transactions for testing monthly aggregations
INSERT INTO transactions (user_id, account_id, category_id, amount, description, transaction_date)
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (SELECT id FROM categories WHERE name = 'Salary' LIMIT 1),
    3500.00,
    'Monthly salary deposit - Previous month',
    CURRENT_DATE - INTERVAL '62 days'
UNION ALL
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (SELECT id FROM categories WHERE name = 'Groceries' LIMIT 1),
    -450.75,
    'Monthly grocery expenses',
    CURRENT_DATE - INTERVAL '65 days'
UNION ALL
SELECT 
    '11111111-1111-1111-1111-111111111111',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    (SELECT id FROM categories WHERE name = 'Investment' LIMIT 1),
    250.50,
    'Dividend payment',
    CURRENT_DATE - INTERVAL '70 days';

-- Sample recurring transactions
INSERT INTO recurring_transactions (user_id, account_id, category_id, amount, description, frequency, start_date, next_due_date)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     (SELECT id FROM categories WHERE name = 'Salary' LIMIT 1),
     3500.00,
     'Monthly salary',
     'monthly',
     '2024-01-01',
     '2024-11-01'),
    ('11111111-1111-1111-1111-111111111111',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     (SELECT id FROM categories WHERE name = 'Utilities' LIMIT 1),
     -125.00,
     'Monthly electricity',
     'monthly',
     '2024-01-15',
     '2024-11-15');

-- Sample budgets
INSERT INTO budgets (user_id, category_id, name, amount, period, start_date)
VALUES 
    ('11111111-1111-1111-1111-111111111111',
     (SELECT id FROM categories WHERE name = 'Groceries' LIMIT 1),
     'Monthly Grocery Budget',
     400.00,
     'monthly',
     '2024-01-01'),
    ('11111111-1111-1111-1111-111111111111',
     (SELECT id FROM categories WHERE name = 'Entertainment' LIMIT 1),
     'Monthly Entertainment Budget',
     150.00,
     'monthly',
     '2024-01-01');

COMMIT;