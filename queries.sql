-- Common Query Patterns for Finance App
-- These queries demonstrate how to efficiently retrieve data using the schema

-- ============================================================================
-- TIME-BASED QUERIES (Optimized for the frontend requirements)
-- ============================================================================

-- 1. Current Week Transactions
-- Gets all transactions for the current week for a specific user
SELECT 
    t.id,
    t.amount,
    t.description,
    t.transaction_date,
    c.name AS category_name,
    c.color AS category_color,
    c.is_income,
    a.name AS account_name,
    t.tags
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
LEFT JOIN accounts a ON t.account_id = a.id
WHERE t.user_id = '11111111-1111-1111-1111-111111111111'
    AND t.transaction_date >= DATE_TRUNC('week', CURRENT_DATE)
    AND t.transaction_date < DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '1 week'
ORDER BY t.transaction_date DESC, t.created_at DESC;

-- 2. Current Month Transactions
-- Gets all transactions for the current month
SELECT 
    t.id,
    t.amount,
    t.description,
    t.transaction_date,
    c.name AS category_name,
    c.color AS category_color,
    c.is_income,
    a.name AS account_name,
    t.tags
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
LEFT JOIN accounts a ON t.account_id = a.id
WHERE t.user_id = '11111111-1111-1111-1111-111111111111'
    AND t.transaction_date >= DATE_TRUNC('month', CURRENT_DATE)
    AND t.transaction_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
ORDER BY t.transaction_date DESC, t.created_at DESC;

-- 3. All-time Transaction History (with pagination)
-- Gets transaction history with pagination for performance
SELECT 
    t.id,
    t.amount,
    t.description,
    t.transaction_date,
    c.name AS category_name,
    c.color AS category_color,
    c.is_income,
    a.name AS account_name,
    t.tags
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
LEFT JOIN accounts a ON t.account_id = a.id
WHERE t.user_id = '11111111-1111-1111-1111-111111111111'
ORDER BY t.transaction_date DESC, t.created_at DESC
LIMIT 50 OFFSET 0; -- Adjust OFFSET for pagination

-- ============================================================================
-- CATEGORY-BASED BREAKDOWNS
-- ============================================================================

-- 4. Current Month Category Breakdown (using aggregation table)
-- Fast query using pre-computed monthly summaries
SELECT 
    c.name AS category_name,
    c.color AS category_color,
    c.is_income,
    SUM(ms.total_income) AS total_income,
    SUM(ms.total_expenses) AS total_expenses,
    SUM(ms.net_amount) AS net_amount,
    SUM(ms.transaction_count) AS transaction_count
FROM monthly_summaries ms
JOIN categories c ON ms.category_id = c.id
WHERE ms.user_id = '11111111-1111-1111-1111-111111111111'
    AND ms.year = EXTRACT(YEAR FROM CURRENT_DATE)
    AND ms.month = EXTRACT(MONTH FROM CURRENT_DATE)
GROUP BY c.id, c.name, c.color, c.is_income
ORDER BY ABS(SUM(ms.net_amount)) DESC;

-- 5. Current Week Category Breakdown (real-time calculation)
-- For more recent data that might not be in monthly summaries yet
SELECT 
    c.name AS category_name,
    c.color AS category_color,
    c.is_income,
    SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END) AS total_income,
    SUM(CASE WHEN t.amount < 0 THEN ABS(t.amount) ELSE 0 END) AS total_expenses,
    SUM(t.amount) AS net_amount,
    COUNT(*) AS transaction_count
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
WHERE t.user_id = '11111111-1111-1111-1111-111111111111'
    AND t.transaction_date >= DATE_TRUNC('week', CURRENT_DATE)
    AND t.transaction_date < DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '1 week'
GROUP BY c.id, c.name, c.color, c.is_income
ORDER BY ABS(SUM(t.amount)) DESC;

-- ============================================================================
-- DASHBOARD SUMMARY QUERIES
-- ============================================================================

-- 6. Account Balances Summary
-- Quick overview of all user accounts
SELECT 
    a.id,
    a.name,
    a.account_type,
    a.balance,
    a.currency,
    a.is_active
FROM accounts a
WHERE a.user_id = '11111111-1111-1111-1111-111111111111'
    AND a.is_active = true
ORDER BY a.balance DESC;

-- 7. Monthly Trends (last 6 months)
-- Shows spending/income trends over time using monthly summaries
SELECT 
    ms.year,
    ms.month,
    SUM(ms.total_income) AS monthly_income,
    SUM(ms.total_expenses) AS monthly_expenses,
    SUM(ms.net_amount) AS monthly_net,
    SUM(ms.transaction_count) AS monthly_transactions
FROM monthly_summaries ms
WHERE ms.user_id = '11111111-1111-1111-1111-111111111111'
    AND (ms.year * 12 + ms.month) >= (EXTRACT(YEAR FROM CURRENT_DATE) * 12 + EXTRACT(MONTH FROM CURRENT_DATE) - 6)
GROUP BY ms.year, ms.month
ORDER BY ms.year DESC, ms.month DESC;

-- ============================================================================
-- BUDGET TRACKING QUERIES
-- ============================================================================

-- 8. Current Month Budget vs Actual Spending
-- Compares budgets with actual spending for the current month
SELECT 
    b.name AS budget_name,
    c.name AS category_name,
    b.amount AS budget_amount,
    COALESCE(SUM(ms.total_expenses), 0) AS actual_spent,
    b.amount - COALESCE(SUM(ms.total_expenses), 0) AS remaining,
    CASE 
        WHEN b.amount > 0 THEN (COALESCE(SUM(ms.total_expenses), 0) / b.amount * 100)
        ELSE 0 
    END AS percentage_used
FROM budgets b
JOIN categories c ON b.category_id = c.id
LEFT JOIN monthly_summaries ms ON b.category_id = ms.category_id 
    AND b.user_id = ms.user_id
    AND ms.year = EXTRACT(YEAR FROM CURRENT_DATE)
    AND ms.month = EXTRACT(MONTH FROM CURRENT_DATE)
WHERE b.user_id = '11111111-1111-1111-1111-111111111111'
    AND b.is_active = true
    AND b.period = 'monthly'
    AND CURRENT_DATE BETWEEN b.start_date AND COALESCE(b.end_date, '2099-12-31')
GROUP BY b.id, b.name, c.name, b.amount
ORDER BY percentage_used DESC;

-- ============================================================================
-- SEARCH AND FILTER QUERIES
-- ============================================================================

-- 9. Text Search Transactions
-- Search transactions by description or category
SELECT 
    t.id,
    t.amount,
    t.description,
    t.transaction_date,
    c.name AS category_name,
    ts_headline('english', t.description, plainto_tsquery('english', 'grocery')) AS highlighted_description
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
WHERE t.user_id = '11111111-1111-1111-1111-111111111111'
    AND (
        to_tsvector('english', t.description) @@ plainto_tsquery('english', 'grocery')
        OR to_tsvector('english', c.name) @@ plainto_tsquery('english', 'grocery')
    )
ORDER BY t.transaction_date DESC;

-- 10. Filter by Tags
-- Find transactions with specific tags
SELECT 
    t.id,
    t.amount,
    t.description,
    t.transaction_date,
    c.name AS category_name,
    t.tags
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
WHERE t.user_id = '11111111-1111-1111-1111-111111111111'
    AND t.tags && ARRAY['food', 'weekly'] -- Contains any of these tags
ORDER BY t.transaction_date DESC;

-- ============================================================================
-- PERFORMANCE OPTIMIZATION QUERIES
-- ============================================================================

-- 11. Refresh Monthly Summaries (for data consistency)
-- This can be run periodically to ensure monthly summaries are up to date
INSERT INTO monthly_summaries (
    user_id, account_id, category_id, year, month,
    total_income, total_expenses, net_amount, transaction_count
)
SELECT 
    t.user_id,
    t.account_id,
    t.category_id,
    EXTRACT(YEAR FROM t.transaction_date)::INTEGER,
    EXTRACT(MONTH FROM t.transaction_date)::INTEGER,
    SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END),
    SUM(CASE WHEN t.amount < 0 THEN ABS(t.amount) ELSE 0 END),
    SUM(t.amount),
    COUNT(*)
FROM transactions t
WHERE t.user_id = '11111111-1111-1111-1111-111111111111'
GROUP BY t.user_id, t.account_id, t.category_id, 
         EXTRACT(YEAR FROM t.transaction_date), 
         EXTRACT(MONTH FROM t.transaction_date)
ON CONFLICT (user_id, account_id, category_id, year, month)
DO UPDATE SET
    total_income = EXCLUDED.total_income,
    total_expenses = EXCLUDED.total_expenses,
    net_amount = EXCLUDED.net_amount,
    transaction_count = EXCLUDED.transaction_count,
    updated_at = CURRENT_TIMESTAMP;

-- 12. Query Performance Analysis
-- Use EXPLAIN ANALYZE to check query performance
EXPLAIN ANALYZE 
SELECT t.*, c.name AS category_name
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
WHERE t.user_id = '11111111-1111-1111-1111-111111111111'
    AND t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY t.transaction_date DESC;