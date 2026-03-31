#!/usr/bin/env bash
# Quick reference for SevaCare URLs and commands
# Usage: ./scripts/info.sh [--urls|--commands|--all]

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../shared/constants/config.sh"

SHOW="${1:-all}"

print_header() {
  echo ""
  cat << EOF
╔══════════════════════════════════════════════════════════════════════╗
║                    🏥 SevaCare Quick Reference                       ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
}

print_urls() {
  cat << EOF

📍 URLS AND ENDPOINTS
═════════════════════════════════════════════════════════════════════

LOCAL ACCESS (Same Machine):
  Frontend:          http://localhost:8087
  Backend API:       http://localhost:8081/api/v1
  Backend Health:    http://localhost:8081/actuator/health
  Public Tenants:    http://localhost:8081/api/v1/public/tenants

NETWORK ACCESS (From Other Machines):
  Local IP:          http://${LOCAL_IP}
  Frontend:          http://${LOCAL_IP}:8087
  Backend API:       http://${LOCAL_IP}:8081/api/v1
  Backend Health:    http://${LOCAL_IP}:8081/actuator/health
  Public Tenants:    http://${LOCAL_IP}:8081/api/v1/public/tenants

DATABASE:
  Host:              ${DB_HOST}
  Port:              ${DB_PORT}
  Database:          ${DB_NAME}
  User:              ${DB_USER}
  JDBC URL:          jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}

EOF
}

print_commands() {
  cat << EOF

📌 USEFUL COMMANDS
═════════════════════════════════════════════════════════════════════

STARTUP:
  All services:               ./scripts/start-local.sh
  Backend only:               ./scripts/start-backend.sh
  Frontend only:              ./scripts/start-frontend.sh [API_URL]

SHUTDOWN:
  Stop all services:          ./scripts/stop-all.sh
  Stop and clean logs:        ./scripts/stop-all.sh --clean-logs

MONITORING:
  Service status:             ./scripts/status.sh
  Service status (network):   ./scripts/status.sh --network
  Health check (one-time):    ./scripts/health-check.sh
  Health check (watch mode):  ./scripts/health-check.sh --watch --interval 10
  Health check (network):     ./scripts/health-check.sh --network

LOGGING:
  View backend logs:          ./scripts/logs.sh backend
  View frontend logs:         ./scripts/logs.sh frontend
  View all logs:              ./scripts/logs.sh all
  Follow backend logs:        ./scripts/logs.sh backend --follow
  List all log files:         ./scripts/logs.sh list
  View last 100 lines:        ./scripts/logs.sh backend --tail 100

HELP:
  This reference:             ./scripts/info.sh
  Show only URLs:             ./scripts/info.sh --urls
  Show only commands:         ./scripts/info.sh --commands

DIRECTORIES:
  Project root:               ${PROJECT_ROOT}
  Backend source:             ${BACKEND_DIR}
  Frontend source:            ${FRONTEND_DIR}
  Log files:                  ${LOGS_DIR}
  Configuration:              ${PROJECT_ROOT}/shared/constants/config.sh

EOF
}

print_quickstart() {
  cat << EOF

🚀 QUICK START
═════════════════════════════════════════════════════════════════════

1. Make scripts executable (first time only):
   chmod +x ${PROJECT_ROOT}/scripts/*.sh

2. Start all services:
   ${PROJECT_ROOT}/scripts/start-local.sh

3. Check service status:
   ${PROJECT_ROOT}/scripts/status.sh

4. View health report:
   ${PROJECT_ROOT}/scripts/health-check.sh

5. Access application:
   • Frontend:   http://localhost:8087
   • Backend:    http://localhost:8081/api/v1

6. Monitor logs in real-time:
   ${PROJECT_ROOT}/scripts/logs.sh backend --follow

7. Stop services when done:
   ${PROJECT_ROOT}/scripts/stop-all.sh

EOF
}

print_docker_info() {
  cat << EOF

🐳 DOCKER COMMANDS (If using Docker)
═════════════════════════════════════════════════════════════════════

Build images:
  docker-compose build

Start services:
  docker-compose up

Start in background:
  docker-compose up -d

View logs:
  docker-compose logs -f backend
  docker-compose logs -f frontend
  docker-compose logs -f postgres

Stop services:
  docker-compose down

Remove volumes (clean start):
  docker-compose down -v

EOF
}

print_environment_info() {
  cat << EOF

⚙️  ENVIRONMENT CONFIGURATION
═════════════════════════════════════════════════════════════════════

Java Version:         ${JAVA_VERSION}
Node Version:         ${NODE_VERSION}
Maven Version:        ${MAVEN_VERSION}
Skip Tests:           ${SKIP_TESTS}

Configuration Files:
  Example config:     ${PROJECT_ROOT}/.env.example
  Local overrides:    ${PROJECT_ROOT}/.env.local

To customize:
  1. Copy .env.example to .env.local (already done)
  2. Edit .env.local with your settings
  3. Scripts automatically source these files

EOF
}

# Main
print_header

case $SHOW in
  --urls)
    print_urls
    ;;
  --commands)
    print_commands
    ;;
  --docker)
    print_docker_info
    ;;
  --env)
    print_environment_info
    ;;
  all|"")
    print_urls
    print_commands
    print_quickstart
    print_environment_info
    ;;
  *)
    print_error "Unknown option: $SHOW"
    echo ""
    echo "Usage: $0 [--urls|--commands|--docker|--env|all]"
    exit 1
    ;;
esac

echo ""
echo "📚 For more information, see:"
echo "   • REFACTORING_PLAN.md - Detailed project structure"
echo "   • shared/constants/config.sh - Configuration source"
echo ""
