#!/usr/bin/env bash
# ───────────────────────────────────────────────
# SevaCare – Docker Compose Deploy Script
# ───────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ACTION="${1:-up}"

case "$ACTION" in
  up)
    echo "═══ Starting SevaCare (Docker Compose) ═══"
    docker compose up --build -d
    echo ""
    echo "  Frontend: http://localhost:8087"
    echo "  Backend:  http://localhost:8081"
    echo "  Database: localhost:5432"
    echo ""
    echo "Use 'docker compose logs -f' to tail logs"
    ;;
  down)
    echo "═══ Stopping SevaCare ═══"
    docker compose down
    ;;
  logs)
    docker compose logs -f
    ;;
  restart)
    echo "═══ Restarting SevaCare ═══"
    docker compose down
    docker compose up --build -d
    ;;
  status)
    docker compose ps
    ;;
  *)
    echo "Usage: $0 {up|down|logs|restart|status}"
    exit 1
    ;;
esac
