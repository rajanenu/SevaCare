#!/usr/bin/env bash
# Start only Backend
# Usage: ./scripts/start-backend.sh

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared/constants/config.sh"

mkdir -p "$LOGS_DIR"

print_banner() {
  cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                🏥 SevaCare - Backend Service                    ║
╚══════════════════════════════════════════════════════════════════╝
EOF
}

print_banner

# Cleanup only on interrupt/termination for this script session.
cleanup_backend_only() {
  if [ -n "${BACKEND_PID:-}" ]; then
    kill "$BACKEND_PID" 2>/dev/null || true
  fi
  kill_port "$BACKEND_PORT"
}
trap cleanup_backend_only INT TERM

# Check PostgreSQL
print_info "Checking PostgreSQL..."
if pg_isready -h $DB_HOST -p $DB_PORT -q 2>/dev/null; then
  print_success "PostgreSQL ready"
else
  print_error "PostgreSQL not running. Start it first!"
  exit 1
fi

# Kill existing backend if running
if ! is_port_available $BACKEND_PORT; then
  print_warning "Killing existing process on port $BACKEND_PORT..."
  kill_port $BACKEND_PORT
  sleep 1
fi

# Build
print_info "Building backend..."
cd "$BACKEND_DIR"

MAVEN_CMD="$(resolve_maven_cmd)" || {
  print_error "Maven not found. Please install Maven $MAVEN_VERSION"
  exit 1
}

$MAVEN_CMD -pl sevacare-api -am \
  -DskipTests=$SKIP_TESTS \
  -T $BUILD_THREADS \
  clean package \
  -q 2>> "$LOGS_DIR/backend-build.log" || {
  print_error "Build failed. Check $LOGS_DIR/backend-build.log"
  tail -n 60 "$LOGS_DIR/backend-build.log" || true
  exit 1
}
print_success "Build complete"

JAR_PATH=$(ls -1 sevacare-api/target/sevacare-api-*.jar 2>/dev/null | grep -v '\.original$' | head -n 1 || true)
if [ -z "$JAR_PATH" ]; then
  print_error "Could not resolve backend jar in sevacare-api/target"
  exit 1
fi

# Start
print_info "Starting backend on $BACKEND_LOCAL_URL..."
java -jar "$JAR_PATH" \
  --server.port=$BACKEND_PORT \
  --spring.datasource.url=$DB_URL \
  --spring.datasource.username=$DB_USER \
  --spring.datasource.password=$DB_PASSWORD \
  >> "$LOGS_DIR/backend.log" 2>&1 &

BACKEND_PID=$!
export BACKEND_PID
print_success "Backend started (PID: $BACKEND_PID)"

# Wait for readiness
print_info "Waiting for backend to be ready..."
if wait_for_service "$BACKEND_LOCAL_URL/api/v1/public/tenants"; then
  print_success "Backend is ready"
else
  print_error "Backend failed to start"
  tail -n 80 "$LOGS_DIR/backend.log" || true
  exit 1
fi

cat << EOF

✅ Backend is running

📍 URL: $BACKEND_LOCAL_URL
🔗 API: $API_BASE_LOCAL
📊 Health: $BACKEND_LOCAL_URL/actuator/health

📋 Logs: $LOGS_DIR/backend.log
⏹️  Stop: Press Ctrl+C

EOF

wait
