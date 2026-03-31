#!/usr/bin/env bash
# Database setup and management for SevaCare
# Usage: ./scripts/db-setup.sh [--init|--migrate|--reset|--check]

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared/constants/config.sh"

COMMAND="${1:-check}"
RESET_CONFIRM="${2:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_db_banner() {
  cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║           🗄️  SevaCare Database Management                      ║
╚══════════════════════════════════════════════════════════════════╝
EOF
}

check_database() {
  print_info "Checking PostgreSQL connection..."
  
  if ! command -v pg_isready &> /dev/null; then
    print_error "pg_isready not found. Install PostgreSQL client tools."
    return 1
  fi
  
  if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -q; then
    print_error "PostgreSQL is not running at $DB_HOST:$DB_PORT"
    return 1
  fi
  
  print_success "PostgreSQL is running on $DB_HOST:$DB_PORT"
  
  # Try to connect to the database
  print_info "Checking database '$DB_NAME'..."
  
  if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    print_success "Connected to database '$DB_NAME'"
    
    # Get database stats
    local table_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")
    print_info "Number of tables: $table_count"
    
    return 0
  else
    print_warning "Cannot connect to database '$DB_NAME'"
    return 1
  fi
}

create_database() {
  print_info "Creating database '$DB_NAME'..."
  
  if ! command -v psql &> /dev/null; then
    print_error "psql not found. Install PostgreSQL client tools."
    return 1
  fi
  
  # Check if database already exists
  if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
    print_warning "Database '$DB_NAME' already exists"
    return 0
  fi
  
  # Create database
  if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;" > /dev/null 2>&1; then
    print_success "Database '$DB_NAME' created successfully"
    return 0
  else
    print_error "Failed to create database '$DB_NAME'"
    return 1
  fi
}

init_database() {
  print_db_banner
  print_info "Initializing SevaCare database..."
  
  # Check PostgreSQL
  if ! check_database > /dev/null 2>&1; then
    print_info "PostgreSQL not running or database not found. Attempting to create..."
    if ! create_database; then
      print_error "Database initialization failed"
      return 1
    fi
  fi
  
  print_success "Database is ready for migrations"
  
  # Suggest running migrations via backend
  echo ""
  print_info "Next steps:"
  echo "  1. Run the backend to apply Flyway migrations:"
  echo "     ./scripts/start-backend.sh"
  echo "  2. Or manually run migrations using:"
  echo "     cd $BACKEND_DIR"
  echo "     mvn flyway:migrate"
  echo ""
}

list_tables() {
  print_info "Tables in database '$DB_NAME':"
  
  if ! command -v psql &> /dev/null; then
    print_error "psql not found"
    return 1
  fi
  
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
    -c "\dt public.*" 2>/dev/null || print_warning "Could not retrieve table list"
}

verify_schemas() {
  print_info "Verifying database schemas..."
  
  if ! command -v psql &> /dev/null; then
    print_error "psql not found"
    return 1
  fi
  
  echo ""
  print_info "Current schemas:"
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
    -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT LIKE 'pg_%' ORDER BY schema_name;" 2>/dev/null || print_warning "Could not retrieve schemas"
  
  echo ""
  print_info "Schema details:"
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
    -c "SELECT schemaname as schema, COUNT(*) as tables FROM pg_tables WHERE schemaname NOT LIKE 'pg_%' GROUP BY schemaname;" 2>/dev/null || print_warning "Could not retrieve schema details"
}

check_status() {
  print_db_banner
  echo ""
  
  print_info "═══ Database Connection ═══"
  if check_database; then
    echo ""
    print_info "═══ Tables ═══"
    list_tables || true
    
    echo ""
    print_info "═══ Schema Information ═══"
    verify_schemas || true
  else
    print_error "Database is not accessible"
  fi
  
  echo ""
}

reset_database() {
  if [ "$RESET_CONFIRM" != "--force" ]; then
    print_error "This will delete all data in the database!"
    read -p "Are you sure? Type 'YES' to confirm: " confirm
    if [ "$confirm" != "YES" ]; then
      print_warning "Reset cancelled"
      return 0
    fi
  fi
  
  print_info "Resetting database '$DB_NAME'..."
  
  if ! command -v psql &> /dev/null; then
    print_error "psql not found"
    return 1
  fi
  
  # Drop and recreate database
  print_warning "Dropping database..."
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
  
  print_info "Creating fresh database..."
  if create_database; then
    print_success "Database reset complete"
    echo ""
    echo "Next: Run the backend to apply migrations"
    echo "  ./scripts/start-backend.sh"
  else
    print_error "Failed to reset database"
  fi
}

# Main execution
case $COMMAND in
  check)
    check_status
    ;;
  init)
    init_database
    ;;
  reset)
    reset_database
    ;;
  tables)
    print_db_banner
    list_tables
    ;;
  schemas)
    print_db_banner
    verify_schemas
    ;;
  *)
    print_error "Unknown command: $COMMAND"
    echo ""
    echo "Usage: $0 [--init|--check|--tables|--schemas|--reset]"
    echo ""
    echo "Commands:"
    echo "  --init       Initialize database and create tables"
    echo "  --check      Check database connection and status"
    echo "  --tables     List all tables in the database"
    echo "  --schemas    Show schema information"
    echo "  --reset      Drop and recreate the database (requires confirmation)"
    exit 1
    ;;
esac
