#!/usr/bin/env bash
# SevaCare Complete Local Stack Starter
# Starts PostgreSQL (if available), Backend, and Frontend
# Usage: ./scripts/start-local.sh [--backend-only|--frontend-only|--all]

set -euo pipefail

# Source shared constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/constants/config.sh"

# Parse arguments
MODE="${1:-all}"

# Create logs directory
mkdir -p "$LOGS_DIR"

# ═══════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════
print_banner() {
  cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                    🏥 SevaCare - Local Stack                     ║
║                     Starting All Services                        ║
╚══════════════════════════════════════════════════════════════════╝
EOF
}

print_banner

# ═══════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════
preflight_check() {
  print_info "Running preflight checks..."
  
  # Check Java
  if ! command -v java &> /dev/null; then
    print_error "Java not found. Please install Java $JAVA_VERSION"
    exit 1
  fi
  print_success "Java: $(java -version 2>&1 | head -1)"
  
  # Check Node
  if ! command -v node &> /dev/null; then
    print_error "Node.js not found. Please install Node.js $NODE_VERSION"
    exit 1
  fi
  print_success "Node.js: $(node -v)"
  
  # Check Maven
  if ! command -v mvn &> /dev/null; then
    print_error "Maven not found. Please install Maven $MAVEN_VERSION"
    exit 1
  fi
  print_success "Maven: $(mvn -v | head -1)"
  
  # Check ports availability
  if ! is_port_available $BACKEND_PORT; then
    print_warning "Port $BACKEND_PORT is already in use. Killing existing process..."
    kill_port $BACKEND_PORT
    sleep 1
  fi
  
  if ! is_port_available $FRONTEND_PORT; then
    print_warning "Port $FRONTEND_PORT is already in use. Killing existing process..."
    kill_port $FRONTEND_PORT
    sleep 1
  fi
  
  print_success "Preflight checks passed"
}

# ═══════════════════════════════════════════════════════════════
# START SERVICES
# ═══════════════════════════════════════════════════════════════

# PostgreSQL Check (optional)
check_postgresql() {
  print_info "Checking PostgreSQL on port $DB_PORT..."
  if pg_isready -h $DB_HOST -p $DB_PORT -q 2>/dev/null; then
    print_success "PostgreSQL is running"
    return 0
  else
    print_warning "PostgreSQL not running on $DB_HOST:$DB_PORT"
    print_info "Make sure PostgreSQL is running manually"
    return 1
  fi
}

# Backend startup
start_backend() {
  print_info "═══ STARTING BACKEND ═══"
  
  if [ ! -d "$BACKEND_DIR" ]; then
    print_error "Backend directory not found: $BACKEND_DIR"
    exit 1
  fi
  
  cd "$BACKEND_DIR"

  local maven_cmd
  if ! maven_cmd="$(resolve_maven_cmd)"; then
    print_error "Maven not found. Please install Maven $MAVEN_VERSION"
    exit 1
  fi
  
  print_info "Building backend..."
  $maven_cmd -pl sevacare-api -am \
    -DskipTests=$SKIP_TESTS \
    -T $BUILD_THREADS \
    clean package \
    -q 2>> "$LOGS_DIR/backend-build.log" || {
    print_error "Backend build failed. Check $LOGS_DIR/backend-build.log"
    exit 1
  }
  print_success "Backend build complete"
  
  print_info "Starting backend on $BACKEND_LOCAL_URL..."
  java -jar sevacare-api/target/*.jar \
    --server.port=$BACKEND_PORT \
    --spring.datasource.url=$DB_URL \
    --spring.datasource.username=$DB_USER \
    --spring.datasource.password=$DB_PASSWORD \
    >> "$LOGS_DIR/backend.log" 2>&1 &
  
  BACKEND_PID=$!
  export BACKEND_PID
  print_success "Backend started (PID: $BACKEND_PID)"
  
  print_info "Waiting for backend to be ready..."
  if wait_for_service "$BACKEND_LOCAL_URL/api/v1/public/tenants" 30; then
    print_success "Backend is ready"
  else
    print_error "Backend failed to start. Check $LOGS_DIR/backend.log"
    exit 1
  fi
}

# Frontend startup
start_frontend() {
  print_info "═══ STARTING FRONTEND ═══"
  
  if [ ! -d "$FRONTEND_DIR" ]; then
    print_error "Frontend directory not found: $FRONTEND_DIR"
    exit 1
  fi
  
  cd "$FRONTEND_DIR"
  
  print_info "Building frontend..."
  export EXPO_PUBLIC_API_BASE_URL=$API_BASE_LOCAL
  npx expo export --platform web -q 2>> "$LOGS_DIR/frontend-build.log" || {
    print_error "Frontend build failed. Check $LOGS_DIR/frontend-build.log"
    exit 1
  }
  print_success "Frontend build complete"
  
  print_info "Starting frontend on $FRONTEND_LOCAL_URL..."
  npx serve -s dist -l $FRONTEND_PORT \
    >> "$LOGS_DIR/frontend.log" 2>&1 &
  
  FRONTEND_PID=$!
  export FRONTEND_PID
  print_success "Frontend started (PID: $FRONTEND_PID)"
  
  print_info "Waiting for frontend to be ready..."
  if wait_for_service "$FRONTEND_LOCAL_URL" 15; then
    print_success "Frontend is ready"
  else
    print_error "Frontend failed to start. Check $LOGS_DIR/frontend.log"
    exit 1
  fi
}

# ═══════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Run preflight
preflight_check

# Check PostgreSQL
check_postgresql

# Start services based on mode
case "$MODE" in
  backend-only)
    start_backend
    ;;
  frontend-only)
    start_frontend
    ;;
  all|*)
    start_backend
    start_frontend
    ;;
esac

# ═══════════════════════════════════════════════════════════════
# DISPLAY SUMMARY
# ═══════════════════════════════════════════════════════════════

cat << EOF

╔══════════════════════════════════════════════════════════════════╗
║                   ✅ SevaCare is running                         ║
╚══════════════════════════════════════════════════════════════════╝

🌐 LOCAL ACCESS:
   Frontend:  $FRONTEND_LOCAL_URL
   Backend:   $BACKEND_LOCAL_URL
   API:       $API_BASE_LOCAL

🌍 NETWORK ACCESS (from other machines):
   Frontend:  $FRONTEND_NETWORK_URL
   Backend:   $BACKEND_NETWORK_URL
   API:       $API_BASE_NETWORK

📊 ENDPOINTS:
   Tenants API:  $API_BASE_LOCAL/public/tenants
   Health Check: $BACKEND_LOCAL_URL/actuator/health

📋 LOGS:
   Backend:   $LOGS_DIR/backend.log
   Frontend:  $LOGS_DIR/frontend.log
   Build:     $LOGS_DIR/backend-build.log
              $LOGS_DIR/frontend-build.log

⏹️  STOP: Press Ctrl+C to stop all services

═══════════════════════════════════════════════════════════════════

EOF

# Keep services running
wait
