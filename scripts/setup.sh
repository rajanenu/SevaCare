#!/usr/bin/env bash
# First-time setup for SevaCare project
# Run this script once to configure and prepare everything
# Usage: ./scripts/setup.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

print_header() {
  cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                                                                        ║
║              🏥 SevaCare - First-Time Setup Wizard                     ║
║                                                                        ║
║              This script will prepare your SevaCare                    ║
║              environment for local development.                        ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
}

print_step() {
  echo ""
  echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    return 1
  fi
  return 0
}

check_prerequisite() {
  local cmd=$1
  local name=$2
  local install_hint=$3
  
  echo -n "  Checking $name................ "
  
  if check_command "$cmd"; then
    local version=$(get_version "$cmd")
    echo -e "${GREEN}✓ Found${NC} ($version)"
    return 0
  else
    echo -e "${RED}✗ Not found${NC}"
    echo "    Install with: $install_hint"
    return 1
  fi
}

get_version() {
  case $1 in
    java)
      java -version 2>&1 | grep -oP '(?<=version ")[^"]*' | head -1 || echo "unknown"
      ;;
    node)
      node --version 2>/dev/null || echo "unknown"
      ;;
    mvn)
      mvn --version 2>/dev/null | head -1 || echo "unknown"
      ;;
    git)
      git --version 2>/dev/null | head -1 || echo "unknown"
      ;;
    docker)
      docker --version 2>/dev/null || echo "unknown"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

check_prerequisites() {
  print_step "Checking Prerequisites"
  
  local missing=0
  
  check_prerequisite "java" "Java 17+" "brew install openjdk@17" || ((missing++))
  check_prerequisite "node" "Node.js 20+" "brew install node" || ((missing++))
  check_prerequisite "mvn" "Maven 3.9+" "brew install maven" || ((missing++))
  check_prerequisite "git" "Git" "brew install git" || ((missing++))
  check_prerequisite "docker" "Docker (optional)" "brew install docker" || true
  
  echo -n "  Checking PostgreSQL............ "
  if check_command "psql"; then
    local version=$(psql --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓ Found${NC} ($version)"
  else
    echo -e "${YELLOW}⚠ Not required but recommended${NC}"
    echo "    For development: brew install postgresql@15"
  fi
  
  if [ $missing -gt 0 ]; then
    echo ""
    print_error "Missing $missing required tool(s). Please install them first."
    return 1
  fi
  
  print_success "All prerequisites satisfied"
  return 0
}

make_scripts_executable() {
  print_step "Making Scripts Executable"
  
  if [ -d "$SCRIPTS_DIR" ]; then
    chmod +x "$SCRIPTS_DIR"/*.sh 2>/dev/null || true
    echo -n "  Setting permissions........... "
    
    if [ -x "$SCRIPTS_DIR/start-local.sh" ]; then
      echo -e "${GREEN}✓ Done${NC}"
      print_success "All scripts are now executable"
    else
      print_warning "Could not make all scripts executable"
    fi
  fi
}

setup_environment_files() {
  print_step "Setting Up Environment Files"
  
  local env_example="$PROJECT_ROOT/.env.example"
  local env_local="$PROJECT_ROOT/.env.local"
  
  if [ ! -f "$env_example" ]; then
    print_warning "Missing .env.example - creating basic version"
    cat > "$env_example" << 'EOF'
# SevaCare Environment Configuration

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=sevacare
DB_USER=postgres
DB_PASSWORD=postgres

# Backend Configuration
BACKEND_PORT=8081
BACKEND_URL=http://localhost:8081
SKIP_TESTS=true

# Frontend Configuration
FRONTEND_PORT=8087
EXPO_PUBLIC_API_BASE_URL=http://localhost:8081/api/v1

# Java Configuration
JAVA_HOME=/usr/libexec/java_home -v 17

# Node/NPM Configuration
NODE_ENV=development
NPM_CONFIG_FETCH_TIMEOUT=60000

# Build Configuration
BUILD_THREADS=4
MAVEN_OPTS=-Xmx2G
EOF
    print_success "Created .env.example"
  else
    print_success "Found .env.example"
  fi
  
  if [ ! -f "$env_local" ]; then
    echo "  Creating .env.local............ " -n
    cp "$env_example" "$env_local"
    echo -e "${GREEN}✓ Done${NC}"
  else
    print_success "Found .env.local"
  fi
}

verify_project_structure() {
  print_step "Verifying Project Structure"
  
  local required_dirs=(
    "sevacare-backend"
    "sevacare-frontend"
    "sevacare-e2e-test"
  )
  
  for dir in "${required_dirs[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
      echo -e "  ${GREEN}✓${NC} $dir"
    else
      echo -e "  ${RED}✗${NC} $dir ${YELLOW}(missing)${NC}"
    fi
  done
}

create_directories() {
  print_step "Creating Required Directories"
  
  local dirs=(
    ".logs"
    "docs"
    "scripts"
    "shared/constants"
    "shared/config"
  )
  
  for dir in "${dirs[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
      echo -e "  ${GREEN}✓${NC} $dir"
    else
      mkdir -p "$PROJECT_ROOT/$dir" 2>/dev/null || true
      if [ -d "$PROJECT_ROOT/$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $dir (created)"
      fi
    fi
  done
}

show_next_steps() {
  cat << 'EOF'

╔════════════════════════════════════════════════════════════════════════╗
║                      ✓ Setup Complete!                                ║
╚════════════════════════════════════════════════════════════════════════╝

🎯 NEXT STEPS:

1. Review configuration:
   cat .env.local

2. Customize if needed:
   nano .env.local

3. Start PostgreSQL (if using local):
   brew services start postgresql@15

4. Initialize database:
   ./scripts/db-setup.sh --init

5. Start the application:
   ./scripts/start-local.sh

6. Verify services are running:
   ./scripts/health-check.sh

7. View URLs and endpoints:
   ./scripts/info.sh

═════════════════════════════════════════════════════════════════════════

📍 QUICK REFERENCES:

Service Startup:          ./scripts/start-local.sh
Service Status:           ./scripts/status.sh
Health Check:             ./scripts/health-check.sh
View Logs:                ./scripts/logs.sh backend --follow
Database Setup:           ./scripts/db-setup.sh --check
Quick Info:               ./scripts/info.sh

═════════════════════════════════════════════════════════════════════════

💡 USEFUL INFORMATION:

Frontend (Local):    http://localhost:8087
Backend API:         http://localhost:8081/api/v1
Backend Health:      http://localhost:8081/actuator/health
Database:            localhost:5432 / sevacare

Log Files:           .logs/ directory
Configuration:       shared/constants/config.sh

═════════════════════════════════════════════════════════════════════════

❓ NEED HELP?

View available commands:  ./scripts/info.sh --commands
See all URLs:             ./scripts/info.sh --urls
Check environment:        ./scripts/info.sh --env

═════════════════════════════════════════════════════════════════════════

EOF
}

# Main execution
main() {
  print_header
  
  echo ""
  read -p "Ready to begin setup? (y/n) " -n 1 -r
  echo ""
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Setup cancelled"
    exit 0
  fi
  
  # Run all setup steps
  if ! check_prerequisites; then
    print_error "Setup failed: Missing prerequisites"
    exit 1
  fi
  
  create_directories
  setup_environment_files
  make_scripts_executable
  verify_project_structure
  
  echo ""
  show_next_steps
  
  print_success "All setup tasks completed!"
  echo ""
  echo "Run: ./scripts/start-local.sh   (to start the application)"
  echo "Or:  ./scripts/info.sh          (for more information)"
  echo ""
}

# Run setup
main "$@"
