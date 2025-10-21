-- Finance App Database Schema
-- Designed for efficient transaction tracking and time-based queries

-- Create database extensions for better performance
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table to store user information
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Categories table for transaction categorization
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    color VARCHAR(7), -- HEX color code
    icon VARCHAR(50),
    is_income BOOLEAN DEFAULT FALSE, -- TRUE for income categories, FALSE for expense
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Accounts table to support multiple accounts per user
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(50) NOT NULL, -- 'checking', 'savings', 'credit_card', 'investment', etc.
    balance DECIMAL(15, 2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'USD',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Transactions table - the core of the finance tracking
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
    
    -- Additional fields for better tracking
    external_id VARCHAR(255), -- For bank import reconciliation
    reference_number VARCHAR(100),
    notes TEXT,
    tags TEXT[], -- Array for flexible tagging
    
    -- Constraints
    CONSTRAINT amount_not_zero CHECK (amount != 0)
);

-- Recurring transactions template
CREATE TABLE recurring_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),
    amount DECIMAL(15, 2) NOT NULL,
    description TEXT,
    frequency VARCHAR(20) NOT NULL, -- 'daily', 'weekly', 'monthly', 'yearly'
    start_date DATE NOT NULL,
    end_date DATE, -- NULL for indefinite
    next_due_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

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
    
    -- Ensure unique entries per user/account/category/month
    CONSTRAINT unique_monthly_summary UNIQUE (user_id, account_id, category_id, year, month)
);

-- Budgets table for spending limits and tracking
CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    period VARCHAR(20) NOT NULL, -- 'monthly', 'weekly', 'yearly'
    start_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for optimal query performance

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

-- Functions and triggers for maintaining data integrity

-- Function to update account balance
CREATE OR REPLACE FUNCTION update_account_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE accounts 
        SET balance = balance + NEW.amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.account_id;
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Adjust for the difference
        UPDATE accounts 
        SET balance = balance - OLD.amount + NEW.amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.account_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE accounts 
        SET balance = balance - OLD.amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = OLD.account_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for account balance updates
CREATE TRIGGER trigger_update_account_balance
    AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_account_balance();

-- Function to update monthly summaries
CREATE OR REPLACE FUNCTION update_monthly_summary()
RETURNS TRIGGER AS $$
DECLARE
    summary_year INTEGER;
    summary_month INTEGER;
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        summary_year := EXTRACT(YEAR FROM NEW.transaction_date);
        summary_month := EXTRACT(MONTH FROM NEW.transaction_date);
        
        INSERT INTO monthly_summaries (
            user_id, account_id, category_id, year, month,
            total_income, total_expenses, net_amount, transaction_count
        )
        VALUES (
            NEW.user_id, NEW.account_id, NEW.category_id,
            summary_year, summary_month,
            CASE WHEN NEW.amount > 0 THEN NEW.amount ELSE 0 END,
            CASE WHEN NEW.amount < 0 THEN ABS(NEW.amount) ELSE 0 END,
            NEW.amount,
            1
        )
        ON CONFLICT (user_id, account_id, category_id, year, month)
        DO UPDATE SET
            total_income = monthly_summaries.total_income + 
                CASE WHEN NEW.amount > 0 THEN NEW.amount ELSE 0 END -
                CASE WHEN TG_OP = 'UPDATE' AND OLD.amount > 0 THEN OLD.amount ELSE 0 END,
            total_expenses = monthly_summaries.total_expenses + 
                CASE WHEN NEW.amount < 0 THEN ABS(NEW.amount) ELSE 0 END -
                CASE WHEN TG_OP = 'UPDATE' AND OLD.amount < 0 THEN ABS(OLD.amount) ELSE 0 END,
            net_amount = monthly_summaries.net_amount + NEW.amount -
                CASE WHEN TG_OP = 'UPDATE' THEN OLD.amount ELSE 0 END,
            transaction_count = monthly_summaries.transaction_count + 
                CASE WHEN TG_OP = 'UPDATE' THEN 0 ELSE 1 END,
            updated_at = CURRENT_TIMESTAMP;
            
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for monthly summaries
CREATE TRIGGER trigger_update_monthly_summary
    AFTER INSERT OR UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_monthly_summary();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers to relevant tables
CREATE TRIGGER trigger_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_accounts_updated_at 
    BEFORE UPDATE ON accounts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_transactions_updated_at 
    BEFORE UPDATE ON transactions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_budgets_updated_at 
    BEFORE UPDATE ON budgets 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();