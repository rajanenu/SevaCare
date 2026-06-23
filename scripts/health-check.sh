#!/usr/bin/env bash
# Health check script for SevaCare services
# Performs comprehensive health checks and generates a report
# Usage: ./scripts/health-check.sh [--watch] [--network]

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared/constants/config.sh"

WATCH_MODE=false
USE_NETWORK=false
WATCH_INTERVAL=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --watch)
      WATCH_MODE=true
      ;;
    --network)
      USE_NETWORK=true
      ;;
    --interval)
      WATCH_INTERVAL="$2"
      shift
      ;;
    *)
      print_error "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Select URL mode
if [ "$USE_NETWORK" = true ]; then
  BACKEND_URL=$BACKEND_NETWORK_URL
  FRONTEND_URL=$FRONTEND_NETWORK_URL
  URL_MODE="NETWORK (${LOCAL_IP})"
else
  BACKEND_URL=$BACKEND_LOCAL_URL
  FRONTEND_URL=$FRONTEND_LOCAL_URL
  URL_MODE="LOCAL (localhost)"
fi

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

HEALTH_PASS=0
HEALTH_FAIL=0

check_endpoint() {
  local name=$1
  local url=$2
  local timeout=${3:-5}
  
  if curl -sf --connect-timeout $timeout --max-time $timeout "$url" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((HEALTH_PASS++))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}"
    ((HEALTH_FAIL++))
    return 1
  fi
}

check_port() {
  local port=$1
  
  if ! is_port_available "$port"; then
    echo -e "${GREEN}✓ LISTENING${NC}"
    return 0
  else
    echo -e "${RED}✗ NOT LISTENING${NC}"
    return 1
  fi
}

print_health_banner() {
  clear
  cat << EOF
╔════════════════════════════════════════════════════════════════════╗
║                   🏥 SevaCare Health Check                         ║
╚════════════════════════════════════════════════════════════════════╝
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Mode: $URL_MODE
${WATCH_MODE:+Watch Mode: ON (intervals: ${WATCH_INTERVAL}s - Press Ctrl+C to stop)}
══════════════════════════════════════════════════════════════════════
EOF
}

run_health_checks() {
  HEALTH_PASS=0
  HEALTH_FAIL=0

  echo ""
  echo -e "${BLUE}PORT STATUS${NC}"
  echo -n "  Backend (8081):....................... "
  check_port 8081
  
  echo -n "  Frontend (8087):....................... "
  check_port 8087
  
  echo -n "  Database (5432):...................... "
  check_port 5432

  echo ""
  echo -e "${BLUE}BACKEND SERVICES${NC}"
  echo "  Health check: $BACKEND_URL/actuator/health"
  echo -n "    Status:............................... "
  check_endpoint "Backend health" "$BACKEND_URL/actuator/health"
  
  echo "  API availability: $BACKEND_URL/api/v1/public/tenants"
  echo -n "    Status:............................... "
  check_endpoint "Backend API" "$BACKEND_URL/api/v1/public/tenants"

  echo ""
  echo -e "${BLUE}FRONTEND SERVICES${NC}"
  echo "  Application: $FRONTEND_URL"
  echo -n "    Status:............................... "
  check_endpoint "Frontend" "$FRONTEND_URL"

  echo ""
  echo -e "${BLUE}DATABASE CONNECTIVITY${NC}"
  if command -v pg_isready &> /dev/null; then
    echo -n "  PostgreSQL (localhost:5432):.......... "
    if pg_isready -h $DB_HOST -p $DB_PORT -q 2>/dev/null; then
      echo -e "${GREEN}✓ CONNECTED${NC}"
      ((HEALTH_PASS++))
    else
      echo -e "${RED}✗ DISCONNECTED${NC}"
      ((HEALTH_FAIL++))
    fi
  else
    echo -n "  PostgreSQL:........................... "
    echo -e "${YELLOW}⚠ SKIPPED (pg_isready not found)${NC}"
  fi

  echo ""
  echo -e "${BLUE}SUMMARY${NC}"
  local total=$((HEALTH_PASS + HEALTH_FAIL))
  local percentage=0
  if [ $total -gt 0 ]; then
    percentage=$((HEALTH_PASS * 100 / total))
  fi
  
  echo "  Total Checks:.......................... $total"
  echo "  Passed:............................... $HEALTH_PASS"
  echo "  Failed:............................... $HEALTH_FAIL"
  
  if [ $percentage -eq 100 ]; then
    echo -e "  Success Rate:......................... ${GREEN}${percentage}%${NC}"
    echo ""
    echo -e "${GREEN}✓ ALL SYSTEMS OPERATIONAL${NC}"
  elif [ $percentage -ge 75 ]; then
    echo -e "  Success Rate:......................... ${YELLOW}${percentage}%${NC}"
    echo ""
    echo -e "${YELLOW}⚠ PARTIAL FAILURE - Check logs${NC}"
  else
    echo -e "  Success Rate:......................... ${RED}${percentage}%${NC}"
    echo ""
    echo -e "${RED}✗ CRITICAL FAILURE${NC}"
  fi
}

# Main loop
if [ "$WATCH_MODE" = true ]; then
  while true; do
    print_health_banner
    run_health_checks
    echo ""
    echo "Waiting ${WATCH_INTERVAL}s for next check (Ctrl+C to stop)..."
    sleep "$WATCH_INTERVAL"
  done
else
  print_health_banner
  run_health_checks
  echo ""
fi
