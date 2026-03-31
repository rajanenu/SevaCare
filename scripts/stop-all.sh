#!/usr/bin/env bash
# Stop all SevaCare services and cleanup ports
# Usage: ./scripts/stop-all.sh

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared/constants/config.sh"

print_banner() {
  cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║              🏥 SevaCare - Stopping Services                    ║
╚══════════════════════════════════════════════════════════════════╝
EOF
}

print_banner

# Stop Backend
print_info "Stopping backend on port $BACKEND_PORT..."
if ! is_port_available $BACKEND_PORT; then
  kill_port $BACKEND_PORT
  print_success "Backend stopped"
else
  print_warning "Backend not running"
fi

# Stop Frontend
print_info "Stopping frontend on port $FRONTEND_PORT..."
if ! is_port_available $FRONTEND_PORT; then
  kill_port $FRONTEND_PORT
  print_success "Frontend stopped"
else
  print_warning "Frontend not running"
fi

# Optional: Stop PostgreSQL connections (local dev only)
print_info "Checking for stale processes..."
pkill -f "java.*sevacare" 2>/dev/null || true
pkill -f "node.*serve" 2>/dev/null || true

# Cleanup logs if requested
if [ "${1:-}" = "--clean-logs" ]; then
  print_info "Cleaning up logs..."
  rm -rf "$LOGS_DIR"
  print_success "Logs cleaned"
fi

cat << EOF

✅ All services stopped

📋 Ports freed:
   Backend: $BACKEND_PORT
   Frontend: $FRONTEND_PORT

EOF

print_success "Cleanup complete"
