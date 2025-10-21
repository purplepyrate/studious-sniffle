-- Migration 004: Database Functions and Triggers
-- Created: 2024-10-21
-- Description: Adds automated triggers for balance updates and data integrity

BEGIN;

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

COMMIT;