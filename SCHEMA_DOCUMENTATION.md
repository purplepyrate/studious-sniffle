# Finance App Database Schema Documentation

## Overview

This database schema is designed for a comprehensive finance application that efficiently tracks user transactions, supports multiple accounts, and provides optimized queries for time-based analysis. The schema prioritizes performance for common frontend queries while maintaining data integrity and flexibility for future enhancements.

## Core Design Principles

### 1. **Performance-First Architecture**
- Optimized indexes for time-based queries (weekly, monthly, all-time views)
- Pre-computed aggregation tables for faster dashboard queries
- Composite indexes for common query patterns

### 2. **Scalability & Multi-tenancy**
- UUID primary keys for distributed systems compatibility
- Proper user isolation with foreign key constraints
- Support for multiple accounts per user

### 3. **Data Integrity**
- Automated balance calculations via database triggers
- Referential integrity with cascading deletes
- Constraint validation for business rules

### 4. **Flexibility**
- Extensible category system with visual customization
- Tag-based classification for flexible organization
- Support for recurring transactions and budgets

## Schema Components

### Core Tables

#### **users**
Stores user account information and authentication details.

**Key Features:**
- UUID primary key for scalability
- Unique constraints on email and username
- Timestamped for audit trails

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### **categories**
Defines transaction categories with visual customization.

**Key Features:**
- Supports both income and expense categories
- Visual customization (color, icon)
- Full-text search capability

```sql
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    color VARCHAR(7), -- HEX color code
    icon VARCHAR(50),
    is_income BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### **accounts**
Manages multiple accounts per user (checking, savings, credit cards, etc.).

**Key Features:**
- Automated balance calculation via triggers
- Support for different currencies
- Soft delete via is_active flag

```sql
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(50) NOT NULL,
    balance DECIMAL(15, 2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'USD',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

#### **transactions**
The core table storing all financial transactions.

**Key Features:**
- Optimized for time-based queries
- Flexible tagging system
- Support for external system integration
- Automated balance updates

```sql
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),
    amount DECIMAL(15, 2) NOT NULL,
    description TEXT,
    transaction_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    external_id VARCHAR(255),
    reference_number VARCHAR(100),
    notes TEXT,
    tags TEXT[],
    
    CONSTRAINT amount_not_zero CHECK (amount != 0)
);
```

### Supporting Tables

#### **recurring_transactions**
Templates for recurring transactions (salary, bills, etc.).

**Use Cases:**
- Automatic transaction generation
- Predictive budgeting
- Reminder systems

#### **budgets**
Budget tracking and spending limits.

**Features:**
- Flexible time periods (monthly, weekly, yearly)
- Category-based budgeting
- Active/inactive states for historical tracking

#### **monthly_summaries**
Pre-computed aggregation table for performance optimization.

**Benefits:**
- Fast dashboard queries
- Historical trend analysis
- Reduced computation load for large datasets

```sql
CREATE TABLE monthly_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id UUID REFERENCES accounts(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    total_income DECIMAL(15, 2) DEFAULT 0.00,
    total_expenses DECIMAL(15, 2) DEFAULT 0.00,
    net_amount DECIMAL(15, 2) DEFAULT 0.00,
    transaction_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_monthly_summary UNIQUE (user_id, account_id, category_id, year, month)
);
```

## Index Strategy

### Time-Based Query Optimization

The schema includes specialized indexes to optimize the most common frontend queries:

#### **Primary Time-Based Indexes**
```sql
-- Essential for weekly/monthly/date-range queries
CREATE INDEX idx_transactions_user_date ON transactions(user_id, transaction_date DESC);
CREATE INDEX idx_transactions_account_date ON transactions(account_id, transaction_date DESC);
CREATE INDEX idx_transactions_category_date ON transactions(category_id, transaction_date DESC);
```

#### **Composite Indexes for Complex Queries**
```sql
-- User + Account + Date queries (account-specific views)
CREATE INDEX idx_transactions_user_account_date ON transactions(user_id, account_id, transaction_date DESC);

-- User + Category + Date queries (category breakdowns)
CREATE INDEX idx_transactions_user_category_date ON transactions(user_id, category_id, transaction_date DESC);
```

#### **Search and Filter Indexes**
```sql
-- Full-text search on descriptions
CREATE INDEX idx_transactions_description_search ON transactions USING GIN(to_tsvector('english', description));

-- Array-based tag searching
CREATE INDEX idx_transactions_tags ON transactions USING GIN(tags);
```

### Index Performance Considerations

1. **Descending Date Order**: All date indexes use DESC order to optimize "latest first" queries
2. **Partial Indexes**: Used for active records to reduce index size
3. **GIN Indexes**: For full-text search and array operations
4. **Composite Indexes**: Cover multiple WHERE clause conditions in single index

## Query Patterns & Performance

### Frontend Query Requirements

#### 1. **Current Week Transactions**
```sql
-- Optimized by idx_transactions_user_date
SELECT t.*, c.name AS category_name
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
WHERE t.user_id = ? 
    AND t.transaction_date >= DATE_TRUNC('week', CURRENT_DATE)
    AND t.transaction_date < DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '1 week'
ORDER BY t.transaction_date DESC;
```

#### 2. **Current Month Transactions**
```sql
-- Optimized by idx_transactions_user_date
SELECT t.*, c.name AS category_name
FROM transactions t
LEFT JOIN categories c ON t.category_id = c.id
WHERE t.user_id = ? 
    AND t.transaction_date >= DATE_TRUNC('month', CURRENT_DATE)
ORDER BY t.transaction_date DESC;
```

#### 3. **Category Breakdowns**
```sql
-- Fast query using monthly_summaries for historical data
SELECT c.name, SUM(ms.total_income), SUM(ms.total_expenses)
FROM monthly_summaries ms
JOIN categories c ON ms.category_id = c.id
WHERE ms.user_id = ? AND ms.year = ? AND ms.month = ?
GROUP BY c.name;
```

### Performance Optimization Strategies

#### **Aggregation Tables**
- `monthly_summaries` pre-computes monthly statistics
- Reduces query time from O(n) to O(1) for historical data
- Updated automatically via triggers

#### **Trigger-Based Automation**
- Account balances updated automatically on transaction changes
- Monthly summaries maintained in real-time
- Consistent data without application logic complexity

#### **Pagination Strategy**
```sql
-- Efficient pagination for large result sets
SELECT * FROM transactions 
WHERE user_id = ? 
ORDER BY transaction_date DESC, created_at DESC
LIMIT 50 OFFSET ?;
```

## Automation & Data Integrity

### Database Triggers

#### **Account Balance Management**
```sql
-- Automatically maintains account balances
CREATE TRIGGER trigger_update_account_balance
    AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_account_balance();
```

#### **Monthly Summary Maintenance**
```sql
-- Keeps aggregation tables synchronized
CREATE TRIGGER trigger_update_monthly_summary
    AFTER INSERT OR UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_monthly_summary();
```

#### **Timestamp Management**
```sql
-- Automatically updates modified timestamps
CREATE TRIGGER trigger_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### Data Consistency Features

1. **Referential Integrity**: Foreign keys with CASCADE DELETE
2. **Check Constraints**: Business rule validation (e.g., non-zero amounts)
3. **Unique Constraints**: Prevent duplicate data
4. **Automated Timestamps**: Track creation and modification times

## Scalability Considerations

### Horizontal Scaling
- UUID primary keys enable cross-database replication
- User-based partitioning possible via user_id
- No auto-incrementing integers that could cause conflicts

### Vertical Scaling
- Indexes optimized for common queries
- Aggregation tables reduce computational load
- Efficient data types (DECIMAL for money, DATE for dates)

### Future Enhancements

#### **Materialized Views** (Alternative to monthly_summaries)
```sql
CREATE MATERIALIZED VIEW user_monthly_stats AS
SELECT user_id, 
       EXTRACT(YEAR FROM transaction_date) as year,
       EXTRACT(MONTH FROM transaction_date) as month,
       SUM(amount) as net_amount,
       COUNT(*) as transaction_count
FROM transactions
GROUP BY user_id, year, month;

-- Refresh periodically
REFRESH MATERIALIZED VIEW user_monthly_stats;
```

#### **Partitioning for Large Datasets**
```sql
-- Partition transactions by date for very large datasets
CREATE TABLE transactions_y2024 PARTITION OF transactions
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

## Migration Strategy

The schema is organized into logical migration files:

1. **001_initial_schema.sql**: Core tables and relationships
2. **002_recurring_and_budgets.sql**: Extended functionality
3. **003_aggregations_and_indexes.sql**: Performance optimizations
4. **004_triggers_and_functions.sql**: Automation and data integrity

This modular approach allows for:
- Incremental deployments
- Easy rollbacks
- Clear dependency tracking
- Version control integration

## Security Considerations

### Data Protection
- User data isolation via foreign key constraints
- No sensitive data in logs (UUIDs instead of sequential IDs)
- Proper indexing prevents full table scans

### Access Patterns
- Row-level security can be implemented using PostgreSQL RLS
- Queries always filtered by user_id
- No cross-user data exposure risk

## Monitoring & Maintenance

### Performance Monitoring
```sql
-- Check index usage
SELECT schemaname, tablename, indexname, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_tup_read DESC;

-- Monitor query performance
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY total_time DESC;
```

### Maintenance Tasks
1. **VACUUM ANALYZE**: Regular statistics updates
2. **REINDEX**: Rebuild indexes if fragmented
3. **Monthly Summary Refresh**: Verify aggregation accuracy

This schema provides a robust foundation for a finance application with excellent performance characteristics and room for future growth.