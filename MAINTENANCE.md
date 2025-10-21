# Database Maintenance Guide

## Regular Maintenance Tasks

### Daily Tasks (Automated)

#### 1. Backup Database
```bash
# Create daily backup
pg_dump -h localhost -U postgres finance_app > backup_$(date +%Y%m%d).sql

# Compress backup
gzip backup_$(date +%Y%m%d).sql

# Keep only last 7 days of backups
find /backup/path -name "backup_*.sql.gz" -mtime +7 -delete
```

#### 2. Monitor Database Size
```sql
-- Check database size
SELECT pg_size_pretty(pg_database_size('finance_app')) as db_size;

-- Check table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Weekly Tasks

#### 1. Update Table Statistics
```sql
-- Update statistics for query optimizer
ANALYZE;

-- For specific high-traffic tables
ANALYZE transactions;
ANALYZE monthly_summaries;
```

#### 2. Check Index Usage
```sql
-- Identify unused indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as size
FROM pg_stat_user_indexes
WHERE idx_tup_read = 0
ORDER BY pg_relation_size(indexname::regclass) DESC;
```

#### 3. Vacuum Analysis
```sql
-- Check tables that need vacuuming
SELECT 
    relname,
    n_dead_tup,
    n_live_tup,
    round(n_dead_tup::float / (n_live_tup + n_dead_tup) * 100, 2) as dead_ratio
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY dead_ratio DESC;
```

### Monthly Tasks

#### 1. Full Database Vacuum
```sql
-- Reclaim space and update statistics
VACUUM ANALYZE;

-- For heavily updated tables
VACUUM FULL transactions; -- Use during maintenance window
```

#### 2. Reindex if Necessary
```sql
-- Check index bloat and reindex if needed
REINDEX INDEX CONCURRENTLY idx_transactions_user_date;
REINDEX INDEX CONCURRENTLY idx_transactions_user_account_date;
```

#### 3. Monthly Summary Verification
```sql
-- Verify monthly summaries accuracy
WITH calculated_summaries AS (
    SELECT 
        user_id,
        account_id,
        category_id,
        EXTRACT(YEAR FROM transaction_date)::INTEGER as year,
        EXTRACT(MONTH FROM transaction_date)::INTEGER as month,
        SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as calc_income,
        SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as calc_expenses,
        SUM(amount) as calc_net,
        COUNT(*) as calc_count
    FROM transactions
    GROUP BY user_id, account_id, category_id, year, month
)
SELECT 
    ms.*,
    cs.calc_income,
    cs.calc_expenses,
    cs.calc_net,
    cs.calc_count,
    CASE 
        WHEN ABS(ms.total_income - cs.calc_income) > 0.01 THEN 'INCOME_MISMATCH'
        WHEN ABS(ms.total_expenses - cs.calc_expenses) > 0.01 THEN 'EXPENSE_MISMATCH'
        WHEN ABS(ms.net_amount - cs.calc_net) > 0.01 THEN 'NET_MISMATCH'
        WHEN ms.transaction_count != cs.calc_count THEN 'COUNT_MISMATCH'
        ELSE 'OK'
    END as status
FROM monthly_summaries ms
JOIN calculated_summaries cs ON (
    ms.user_id = cs.user_id AND
    ms.account_id = cs.account_id AND
    ms.category_id = cs.category_id AND
    ms.year = cs.year AND
    ms.month = cs.month
)
WHERE ABS(ms.total_income - cs.calc_income) > 0.01
   OR ABS(ms.total_expenses - cs.calc_expenses) > 0.01
   OR ABS(ms.net_amount - cs.calc_net) > 0.01
   OR ms.transaction_count != cs.calc_count;
```

## Performance Monitoring

### Query Performance
```sql
-- Enable query statistics (run once)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Monitor slow queries
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;
```

### Connection Monitoring
```sql
-- Check active connections
SELECT 
    state,
    count(*) as connections
FROM pg_stat_activity
WHERE datname = 'finance_app'
GROUP BY state;

-- Long-running queries
SELECT 
    pid,
    usename,
    state,
    query_start,
    now() - query_start as duration,
    query
FROM pg_stat_activity
WHERE datname = 'finance_app'
    AND state != 'idle'
    AND now() - query_start > interval '5 minutes'
ORDER BY duration DESC;
```

### Lock Monitoring
```sql
-- Check for blocking queries
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS current_statement_in_blocking_process
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

## Data Integrity Checks

### Account Balance Verification
```sql
-- Verify account balances match transaction totals
WITH transaction_balances AS (
    SELECT 
        account_id,
        SUM(amount) as calculated_balance
    FROM transactions
    GROUP BY account_id
)
SELECT 
    a.id,
    a.name,
    a.balance as stored_balance,
    COALESCE(tb.calculated_balance, 0) as calculated_balance,
    a.balance - COALESCE(tb.calculated_balance, 0) as difference
FROM accounts a
LEFT JOIN transaction_balances tb ON a.id = tb.account_id
WHERE ABS(a.balance - COALESCE(tb.calculated_balance, 0)) > 0.01;
```

### Referential Integrity Check
```sql
-- Check for orphaned records
-- Transactions without valid accounts
SELECT COUNT(*) as orphaned_transactions
FROM transactions t
LEFT JOIN accounts a ON t.account_id = a.id
WHERE a.id IS NULL;

-- Transactions without valid users
SELECT COUNT(*) as orphaned_user_transactions
FROM transactions t
LEFT JOIN users u ON t.user_id = u.id
WHERE u.id IS NULL;

-- Account without valid users
SELECT COUNT(*) as orphaned_accounts
FROM accounts a
LEFT JOIN users u ON a.user_id = u.id
WHERE u.id IS NULL;
```

## Optimization Recommendations

### 1. Partitioning for Large Datasets
```sql
-- If transactions table grows very large (>10M records), consider partitioning
-- Example: Partition by year
CREATE TABLE transactions_y2024 PARTITION OF transactions
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE transactions_y2025 PARTITION OF transactions
FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
```

### 2. Archive Old Data
```sql
-- Archive transactions older than 7 years
CREATE TABLE transactions_archive (LIKE transactions INCLUDING ALL);

-- Move old data
WITH moved_data AS (
    DELETE FROM transactions 
    WHERE transaction_date < CURRENT_DATE - INTERVAL '7 years'
    RETURNING *
)
INSERT INTO transactions_archive SELECT * FROM moved_data;
```

### 3. Connection Pooling
Consider implementing connection pooling with:
- **PgBouncer** for PostgreSQL connection pooling
- **Connection pool sizing**: Usually 2-4x CPU cores for web applications
- **Prepared statements** for frequently executed queries

## Alert Conditions

### Set up monitoring alerts for:

1. **Database Size Growth**
   - Alert when database size grows >20% week-over-week
   - Alert when free disk space <20%

2. **Performance Degradation**
   - Alert when average query time >500ms
   - Alert when active connections >80% of max_connections

3. **Data Integrity Issues**
   - Alert when account balance mismatches detected
   - Alert when orphaned records found

4. **Backup Failures**
   - Alert when daily backup fails
   - Alert when backup size is significantly different from previous day

## Troubleshooting Common Issues

### High CPU Usage
```sql
-- Identify resource-intensive queries
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    (total_time / sum(total_time) OVER ()) * 100 AS percentage
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 5;
```

### Lock Contention
```sql
-- Find tables with most locks
SELECT 
    t.schemaname,
    t.tablename,
    l.mode,
    count(*)
FROM pg_locks l
JOIN pg_stat_user_tables t ON l.relation = t.relid
GROUP BY t.schemaname, t.tablename, l.mode
ORDER BY count(*) DESC;
```

### Slow Query Investigation
```sql
-- Explain analyze for slow queries
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) 
SELECT t.*, c.name 
FROM transactions t 
LEFT JOIN categories c ON t.category_id = c.id 
WHERE t.user_id = '11111111-1111-1111-1111-111111111111'
    AND t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY t.transaction_date DESC;
```

This maintenance guide ensures your finance app database remains performant, reliable, and accurate over time.