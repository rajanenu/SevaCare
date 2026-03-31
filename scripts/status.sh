#!/usr/bin/env bash
# Check status of all SevaCare services
# Usage: ./scripts/status.sh [--network]

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared/constants/config.sh"

USE_NETWORK="${1:-}"

if [ "$USE_NETWORK" = "--network" ]; then
  BACKEND_URL=$BACKEND_NETWORK_URL
  FRONTEND_URL=$FRONTEND_NETWORK_URL
else
  BACKEND_URL=$BACKEND_LOCAL_URL
  FRONTEND_URL=$FRONTEND_LOCAL_URL
fi

print_banner() {
  cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║               🏥 SevaCare - Service Status                      ║
╚══════════════════════════════════════════════════════════════════╝
EOF
}

print_status() {
  service=$1
  port=$2
  url=$3
  
  if ! is_port_available $port; then
    # Port is in use, try to get more details
    if curl -sf "$url" > /dev/null 2>&1; then
      print_success "$service is RUNNING on $url"
    else
      print_warning "$service might be running, but failed health check"
    fi
  else
    print_error "$service is NOT RUNNING"
  fi
}

print_banner

print_info "═══ PORT STATUS ═══"
print_status "Backend" $BACKEND_PORT "$BACKEND_URL"
print_status "Frontend" $FRONTEND_PORT "$FRONTEND_URL"

echo ""
print_info "═══ DATABASE STATUS ═══"
if pg_isready -h $DB_HOST -p $DB_PORT -q 2>/dev/null; then
  print_success "PostgreSQL is running on $DB_HOST:$DB_PORT"
else
  print_error "PostgreSQL is NOT running"
fi

echo ""
print_info "═══ ENDPOINT CHECKS ═══"

# Backend health
print_info "Backend health: $BACKEND_URL/actuator/health"
if curl -sf "$BACKEND_URL/actuator/health" > /dev/null 2>&1; then
  print_success "Backend health check passed"
else
  print_warning "Backend health check failed / unavailable"
fi

# Frontend
print_info "Frontend: $FRONTEND_URL"
if curl -sf "$FRONTEND_URL" > /dev/null 2>&1; then
  print_success "Frontend is responsive"
else
  print_warning "Frontend check failed / unavailable"
fi

echo ""
print_info "═══ CONFIGURATION ═══"
if [ "$USE_NETWORK" = "--network" ]; then
  echo "Mode: NETWORK"
  echo "Local IP: $LOCAL_IP"
  echo "Backend: $BACKEND_NETWORK_URL"
  echo "Frontend: $FRONTEND_NETWORK_URL"
else
  echo "Mode: LOCAL"
  echo "Backend: $BACKEND_LOCAL_URL"
  echo "Frontend: $FRONTEND_LOCAL_URL"
  echo ""
  echo "For network access, use: ./scripts/status.sh --network"
  echo "Your local IP: $LOCAL_IP"
fi

echo ""
print_success "Status check complete"
