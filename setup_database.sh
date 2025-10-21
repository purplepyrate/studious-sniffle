#!/bin/bash

# Finance App Database Setup Script
# This script initializes the database with the complete schema

set -e  # Exit on any error

# Default database configuration
DB_NAME="${DB_NAME:-finance_app}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

echo "🚀 Setting up Finance App Database..."
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Host: $DB_HOST:$DB_PORT"
echo ""

# Function to execute SQL file
execute_sql() {
    local file=$1
    local description=$2
    
    echo "📄 Executing: $description"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file"
    echo "✅ Completed: $description"
    echo ""
}

# Check if database exists, create if it doesn't
echo "🔍 Checking if database exists..."
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    echo "📦 Creating database '$DB_NAME'..."
    createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
    echo "✅ Database created successfully"
else
    echo "✅ Database '$DB_NAME' already exists"
fi
echo ""

# Run migrations in order
echo "🔨 Running database migrations..."

# Check if migrations directory exists
if [ ! -d "migrations" ]; then
    echo "❌ Migrations directory not found!"
    echo "Please ensure you're running this script from the project root directory."
    exit 1
fi

# Execute migrations in order
execute_sql "migrations/001_initial_schema.sql" "Initial Schema (Users, Categories, Accounts, Transactions)"
execute_sql "migrations/002_recurring_and_budgets.sql" "Recurring Transactions and Budgets"
execute_sql "migrations/003_aggregations_and_indexes.sql" "Aggregation Tables and Performance Indexes"
execute_sql "migrations/004_triggers_and_functions.sql" "Database Functions and Triggers"

echo "🎉 Database schema setup completed successfully!"
echo ""

# Ask if user wants to load sample data
read -p "📊 Would you like to load sample data for testing? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📊 Loading sample data..."
    execute_sql "sample_data.sql" "Sample Data for Testing"
    echo "🎉 Sample data loaded successfully!"
    
    echo ""
    echo "📈 Sample user credentials for testing:"
    echo "   User 1: john.doe@example.com (ID: 11111111-1111-1111-1111-111111111111)"
    echo "   User 2: jane.smith@example.com (ID: 22222222-2222-2222-2222-222222222222)"
else
    echo "⏭️  Skipping sample data loading."
fi

echo ""
echo "🔍 Database Information:"
echo "   Tables created: $(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';")"
echo "   Indexes created: $(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT count(*) FROM pg_indexes WHERE schemaname = 'public';")"
echo "   Functions created: $(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT count(*) FROM pg_proc WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');")"

echo ""
echo "🎯 Next Steps:"
echo "   1. Review the schema documentation: SCHEMA_DOCUMENTATION.md"
echo "   2. Check sample queries: queries.sql"
echo "   3. Configure your application to connect to the database"
echo "   4. Consider setting up regular maintenance tasks (VACUUM, ANALYZE)"
echo ""
echo "✅ Setup complete! Your finance app database is ready to use."