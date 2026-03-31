#!/usr/bin/env bash
# Start only Frontend
# Usage: ./scripts/start-frontend.sh [api_url]
# Example: ./scripts/start-frontend.sh http://localhost:8081/api/v1

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared/constants/config.sh"

mkdir -p "$LOGS_DIR"

API_URL="${1:-$API_BASE_LOCAL}"

print_banner() {
  cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║               🌐 SevaCare - Frontend Service                    ║
╚══════════════════════════════════════════════════════════════════╝
EOF
}

print_banner

# Cleanup on exit
trap cleanup EXIT INT TERM

# Kill existing frontend if running
if ! is_port_available $FRONTEND_PORT; then
  print_warning "Killing existing process on port $FRONTEND_PORT..."
  kill_port $FRONTEND_PORT
  sleep 1
fi

# Build
print_info "Building frontend..."
cd "$FRONTEND_DIR"
export EXPO_PUBLIC_API_BASE_URL=$API_URL
npx expo export --platform web -q 2>> "$LOGS_DIR/frontend-build.log" || {
  print_error "Build failed. Check $LOGS_DIR/frontend-build.log"
  exit 1
}
print_success "Build complete"

# Start
print_info "Starting frontend on $FRONTEND_LOCAL_URL..."
npx serve -s dist -l $FRONTEND_PORT \
  >> "$LOGS_DIR/frontend.log" 2>&1 &

FRONTEND_PID=$!
export FRONTEND_PID
print_success "Frontend started (PID: $FRONTEND_PID)"

# Wait for readiness
print_info "Waiting for frontend to be ready..."
if wait_for_service "$FRONTEND_LOCAL_URL"; then
  print_success "Frontend is ready"
else
  print_error "Frontend failed to start"
  exit 1
fi

cat << EOF

✅ Frontend is running

📍 URL: $FRONTEND_LOCAL_URL
🔗 API: $API_URL

📋 Logs: $LOGS_DIR/frontend.log
⏹️  Stop: Press Ctrl+C

EOF

wait
