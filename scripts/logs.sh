#!/usr/bin/env bash
# View and monitor logs for SevaCare services
# Usage: ./scripts/logs.sh [backend|frontend|all] [--tail N] [--follow]

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared/constants/config.sh"

SERVICE="${1:-all}"
TAIL_LINES=50
FOLLOW_MODE=false

while [[ $# -gt 1 ]]; do
  case $2 in
    --tail)
      TAIL_LINES="$3"
      shift 2
      ;;
    --follow)
      FOLLOW_MODE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

print_log_banner() {
  local service=$1
  cat << EOF
╔══════════════════════════════════════════════════════════════════╗
║  📋 $service Logs
║  Updated: $(date '+%Y-%m-%d %H:%M:%S')
╚══════════════════════════════════════════════════════════════════╝
EOF
}

show_backend_logs() {
  if [ -f "$LOGS_DIR/backend.log" ]; then
    print_log_banner "Backend Service"
    if [ "$FOLLOW_MODE" = true ]; then
      tail -f "$LOGS_DIR/backend.log"
    else
      tail -n "$TAIL_LINES" "$LOGS_DIR/backend.log"
    fi
  else
    print_error "Backend log not found: $LOGS_DIR/backend.log"
    return 1
  fi
  
  if [ -f "$LOGS_DIR/backend-build.log" ]; then
    echo ""
    print_log_banner "Backend Build Log"
    tail -n 20 "$LOGS_DIR/backend-build.log"
  fi
}

show_frontend_logs() {
  if [ -f "$LOGS_DIR/frontend.log" ]; then
    print_log_banner "Frontend Service"
    if [ "$FOLLOW_MODE" = true ]; then
      tail -f "$LOGS_DIR/frontend.log"
    else
      tail -n "$TAIL_LINES" "$LOGS_DIR/frontend.log"
    fi
  else
    print_error "Frontend log not found: $LOGS_DIR/frontend.log"
    return 1
  fi
  
  if [ -f "$LOGS_DIR/frontend-build.log" ]; then
    echo ""
    print_log_banner "Frontend Build Log"
    tail -n 20 "$LOGS_DIR/frontend-build.log"
  fi
}

show_all_logs() {
  echo ""
  show_backend_logs || true
  echo ""
  show_frontend_logs || true
}

list_available_logs() {
  print_info "Available log files in $LOGS_DIR:"
  if [ -d "$LOGS_DIR" ] && [ "$(ls -A $LOGS_DIR)" ]; then
    ls -lh "$LOGS_DIR"/*.log 2>/dev/null || print_warning "No log files found"
  else
    print_warning "No logs directory or it's empty"
  fi
}

case $SERVICE in
  backend)
    show_backend_logs
    ;;
  frontend)
    show_frontend_logs
    ;;
  all)
    show_all_logs
    ;;
  list)
    list_available_logs
    ;;
  *)
    print_error "Unknown service: $SERVICE"
    print_info "Usage: $0 [backend|frontend|all|list] [--tail N] [--follow]"
    exit 1
    ;;
esac
