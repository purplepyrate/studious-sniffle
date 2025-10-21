# Entity Relationship Diagram

## Visual Schema Overview

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│     USERS       │         │   CATEGORIES    │         │    ACCOUNTS     │
├─────────────────┤         ├─────────────────┤         ├─────────────────┤
│ id (PK)         │         │ id (PK)         │         │ id (PK)         │
│ email           │         │ name            │         │ user_id (FK)    │
│ username        │         │ description     │         │ name            │
│ first_name      │         │ color           │         │ account_type    │
│ last_name       │         │ icon            │         │ balance         │
│ created_at      │         │ is_income       │         │ currency        │
│ updated_at      │         │ created_at      │         │ is_active       │
└─────────────────┘         └─────────────────┘         │ created_at      │
         │                           │                   │ updated_at      │
         │                           │                   └─────────────────┘
         │                           │                           │
         │                           │                           │
         └─────────────┐             │             ┌─────────────┘
                       │             │             │
                       ▼             ▼             ▼
                 ┌─────────────────────────────────────┐
                 │           TRANSACTIONS              │
                 ├─────────────────────────────────────┤
                 │ id (PK)                             │
                 │ user_id (FK) ──────────────────────┐│
                 │ account_id (FK) ────────────────┐  ││
                 │ category_id (FK) ──────────┐    │  ││
                 │ amount                      │    │  ││
                 │ description                 │    │  ││
                 │ transaction_date            │    │  ││
                 │ created_at                  │    │  ││
                 │ updated_at                  │    │  ││
                 │ external_id                 │    │  ││
                 │ reference_number            │    │  ││
                 │ notes                       │    │  ││
                 │ tags[]                      │    │  ││
                 └─────────────────────────────┼────┼──┼┘
                                               │    │  │
         ┌─────────────────────────────────────┘    │  │
         │                                          │  │
         ▼                                          │  │
┌─────────────────┐                                 │  │
│ MONTHLY_SUMMARIES│                                │  │
├─────────────────┤                                 │  │
│ id (PK)         │                                 │  │
│ user_id (FK)    │◄────────────────────────────────┘  │
│ account_id (FK) │◄───────────────────────────────────┘
│ category_id (FK)│◄───────────────────────────────────┐
│ year            │                                    │
│ month           │                                    │
│ total_income    │                                    │
│ total_expenses  │                                    │
│ net_amount      │                                    │
│ transaction_count│                                   │
│ created_at      │                                    │
│ updated_at      │                                    │
└─────────────────┘                                    │
                                                       │
┌─────────────────┐         ┌─────────────────┐        │
│ RECURRING_TRANS │         │     BUDGETS     │        │
├─────────────────┤         ├─────────────────┤        │
│ id (PK)         │         │ id (PK)         │        │
│ user_id (FK)    │         │ user_id (FK)    │        │
│ account_id (FK) │         │ category_id (FK)│◄───────┘
│ category_id (FK)│         │ name            │
│ amount          │         │ amount          │
│ description     │         │ period          │
│ frequency       │         │ start_date      │
│ start_date      │         │ end_date        │
│ end_date        │         │ is_active       │
│ next_due_date   │         │ created_at      │
│ is_active       │         │ updated_at      │
│ created_at      │         └─────────────────┘
│ updated_at      │
└─────────────────┘
```

## Relationships

### Primary Relationships

1. **users → accounts** (1:N)
   - One user can have multiple accounts
   - Cascade delete: removing user removes all accounts

2. **users → transactions** (1:N) 
   - One user can have multiple transactions
   - Cascade delete: removing user removes all transactions

3. **accounts → transactions** (1:N)
   - One account can have multiple transactions
   - Cascade delete: removing account removes all transactions

4. **categories → transactions** (1:N)
   - One category can be used by multiple transactions
   - NULL allowed: transactions can exist without category

### Secondary Relationships

5. **users → recurring_transactions** (1:N)
   - One user can have multiple recurring transaction templates

6. **users → budgets** (1:N)
   - One user can have multiple budgets

7. **categories → budgets** (1:N)
   - One category can have multiple budgets (different time periods)

8. **users → monthly_summaries** (1:N)
   - Pre-computed aggregations per user

### Aggregation Relationships

9. **monthly_summaries** references:
   - **users** (required)
   - **accounts** (optional - for account-specific summaries)
   - **categories** (optional - for category-specific summaries)

## Key Design Features

### Data Integrity
- All foreign keys use CASCADE DELETE for proper cleanup
- Check constraints ensure business rules (e.g., non-zero amounts)
- Unique constraints prevent data duplication

### Performance Optimization
- Multiple composite indexes on transactions table
- Partial indexes for active records only
- GIN indexes for full-text search and array operations

### Flexibility
- Optional category_id allows uncategorized transactions
- Tag arrays enable flexible transaction organization
- Support for multiple currencies per account
- Extensible account types

### Automation
- Triggers automatically maintain account balances
- Triggers keep monthly_summaries synchronized
- Automatic timestamp updates on record changes

## Index Strategy Summary

### Critical Performance Indexes
```sql
-- Time-based queries (most important)
idx_transactions_user_date (user_id, transaction_date DESC)
idx_transactions_user_account_date (user_id, account_id, transaction_date DESC)
idx_transactions_user_category_date (user_id, category_id, transaction_date DESC)

-- Search and filtering
idx_transactions_tags (GIN index on tags array)
idx_transactions_description_search (GIN full-text index)

-- Active records optimization
idx_accounts_user_active (user_id WHERE is_active = true)
idx_budgets_user_active (user_id WHERE is_active = true)
```

This ER design ensures:
- ✅ Efficient time-based queries (week, month, all-time)
- ✅ Fast category breakdowns via aggregation tables
- ✅ Proper multi-user isolation
- ✅ Automated data consistency
- ✅ Scalable performance characteristics