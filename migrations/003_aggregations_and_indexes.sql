-- Migration 003: Aggregation Tables and Performance Indexes
-- Created: 2024-10-21
-- Description: Adds monthly summaries table and optimized indexes for time-based queries

BEGIN;

-- Monthly aggregations for performance optimization
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

-- Primary indexes for transactions (most queried table)
CREATE INDEX idx_transactions_user_date ON transactions(user_id, transaction_date DESC);
CREATE INDEX idx_transactions_account_date ON transactions(account_id, transaction_date DESC);
CREATE INDEX idx_transactions_category_date ON transactions(category_id, transaction_date DESC);
CREATE INDEX idx_transactions_date_amount ON transactions(transaction_date DESC, amount);
CREATE INDEX idx_transactions_user_created ON transactions(user_id, created_at DESC);

-- Composite indexes for common query patterns
CREATE INDEX idx_transactions_user_account_date ON transactions(user_id, account_id, transaction_date DESC);
CREATE INDEX idx_transactions_user_category_date ON transactions(user_id, category_id, transaction_date DESC);

-- Partial indexes for active records
CREATE INDEX idx_accounts_user_active ON accounts(user_id) WHERE is_active = TRUE;
CREATE INDEX idx_budgets_user_active ON budgets(user_id) WHERE is_active = TRUE;
CREATE INDEX idx_recurring_user_active ON recurring_transactions(user_id) WHERE is_active = TRUE;

-- GIN index for tags array searches
CREATE INDEX idx_transactions_tags ON transactions USING GIN(tags);

-- Monthly summaries indexes
CREATE INDEX idx_monthly_summaries_user_date ON monthly_summaries(user_id, year DESC, month DESC);
CREATE INDEX idx_monthly_summaries_category_date ON monthly_summaries(category_id, year DESC, month DESC);

-- Text search indexes
CREATE INDEX idx_transactions_description_search ON transactions USING GIN(to_tsvector('english', description));
CREATE INDEX idx_categories_name_search ON categories USING GIN(to_tsvector('english', name));

COMMIT;