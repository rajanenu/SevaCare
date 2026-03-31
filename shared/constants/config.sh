#!/usr/bin/env bash
# SevaCare Shared Constants and Configuration
# Source this file in deployment scripts

# ═══════════════════════════════════════════════════════════════
# PROJECT STRUCTURE
# ═══════════════════════════════════════════════════════════════
export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export BACKEND_DIR="$PROJECT_ROOT/sevacare-backend"
export FRONTEND_DIR="$PROJECT_ROOT/sevacare-frontend"
export E2E_DIR="$PROJECT_ROOT/sevacare-e2e-test"
export DEPLOY_DIR="$PROJECT_ROOT/sevacare-deploy"
export SCRIPTS_DIR="$PROJECT_ROOT/scripts"
export LOGS_DIR="$PROJECT_ROOT/.logs"

ENV_FILE="$PROJECT_ROOT/.env.local"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# ═══════════════════════════════════════════════════════════════
# PORT CONFIGURATION
# ═══════════════════════════════════════════════════════════════
export BACKEND_PORT="${BACKEND_PORT:-8081}"
export FRONTEND_PORT="${FRONTEND_PORT:-8087}"
export DB_PORT="${DB_PORT:-5432}"
export MAIL_PORT="${MAIL_PORT:-1025}"
export MAILUI_PORT="${MAILUI_PORT:-8025}"

# ═══════════════════════════════════════════════════════════════
# DATABASE CONFIGURATION
# ═══════════════════════════════════════════════════════════════
export DB_HOST="${DB_HOST:-localhost}"
export DB_NAME="${DB_NAME:-seva_care}"
export DB_USER="${DB_USER:-postgres}"
export DB_PASSWORD="${DB_PASSWORD:-postgres}"
export DB_URL="${DB_URL:-jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME}"

# ═══════════════════════════════════════════════════════════════
# SERVICE URLS - LOCAL
# ═══════════════════════════════════════════════════════════════
export BACKEND_LOCAL_URL="http://localhost:$BACKEND_PORT"
export FRONTEND_LOCAL_URL="http://localhost:$FRONTEND_PORT"
export API_BASE_LOCAL="$BACKEND_LOCAL_URL/api/v1"

# ═══════════════════════════════════════════════════════════════
# SERVICE URLS - NETWORK (requires LOCAL_IP)
# ═══════════════════════════════════════════════════════════════
get_local_ip() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}'
  else
    # Linux
    hostname -I | awk '{print $1}'
  fi
}

export LOCAL_IP="${LOCAL_IP:-$(get_local_ip)}"
export BACKEND_NETWORK_URL="http://$LOCAL_IP:$BACKEND_PORT"
export FRONTEND_NETWORK_URL="http://$LOCAL_IP:$FRONTEND_PORT"
export API_BASE_NETWORK="$BACKEND_NETWORK_URL/api/v1"

# ═══════════════════════════════════════════════════════════════
# BUILD CONFIGURATION
# ═══════════════════════════════════════════════════════════════
export MAVEN_VERSION="3.9.x"
export JAVA_VERSION="21"
export NODE_VERSION="20.x"
export SKIP_TESTS="true"
export BUILD_THREADS="4"

resolve_maven_cmd() {
  if [ -x "$BACKEND_DIR/mvnw" ]; then
    echo "./mvnw"
    return 0
  fi

  if command -v mvn > /dev/null 2>&1; then
    echo "mvn"
    return 0
  fi

  return 1
}

# ═══════════════════════════════════════════════════════════════
# PROCESS IDs (for cleanup)
# ═══════════════════════════════════════════════════════════════
export BACKEND_PID=""
export FRONTEND_PID=""
export DB_PID=""

# ═══════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Print colored output
print_info() {
  echo -e "\033[34m→\033[0m $1"
}

print_success() {
  echo -e "\033[32m✓\033[0m $1"
}

print_error() {
  echo -e "\033[31m✗\033[0m $1" >&2
}

print_warning() {
  echo -e "\033[33m⚠\033[0m $1"
}

# Check if service is running on port
is_port_available() {
  port=$1
  if command -v lsof &> /dev/null; then
    lsof -ti:$port > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      return 1  # Port is in use
    fi
  elif command -v netstat &> /dev/null; then
    netstat -tuln | grep :$port > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      return 1
    fi
  fi
  return 0  # Port is available
}

# Wait for service readiness
wait_for_service() {
  url=$1
  max_attempts=${2:-30}
  attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    if curl -sf "$url" > /dev/null 2>&1; then
      return 0
    fi
    print_info "Waiting for $url... ($attempt/$max_attempts)"
    sleep 2
    ((attempt++))
  done
  
  return 1
}

# Kill process by port
kill_port() {
  port=$1
  if command -v lsof &> /dev/null; then
    lsof -ti:$port | xargs kill -9 2>/dev/null || true
  elif command -v fuser &> /dev/null; then
    fuser -k $port/tcp 2>/dev/null || true
  fi
}

# Cleanup function
cleanup() {
  print_info "Cleaning up processes..."
  [ -n "$BACKEND_PID" ] && kill $BACKEND_PID 2>/dev/null || true
  [ -n "$FRONTEND_PID" ] && kill $FRONTEND_PID 2>/dev/null || true
  kill_port $BACKEND_PORT
  kill_port $FRONTEND_PORT
  print_success "Cleanup complete"
}

# ═══════════════════════════════════════════════════════════════
# EXPORT ALL
# ═══════════════════════════════════════════════════════════════
export -f print_info print_success print_error print_warning
export -f is_port_available wait_for_service kill_port cleanup resolve_maven_cmd
