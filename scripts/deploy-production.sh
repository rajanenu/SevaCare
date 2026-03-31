#!/usr/bin/env bash
# Deploy production stack using Docker Compose production file

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_DIR="$PROJECT_ROOT/sevacare-deploy"
ENV_FILE="${1:-$PROJECT_ROOT/.env.production}"
ACTION="${2:-up}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE"
  echo "Create from template: cp $PROJECT_ROOT/.env.production.example $PROJECT_ROOT/.env.production"
  exit 1
fi

cd "$DEPLOY_DIR"

case "$ACTION" in
  up)
    docker compose --env-file "$ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml up --build -d
    ;;
  down)
    docker compose --env-file "$ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml down
    ;;
  restart)
    docker compose --env-file "$ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml down
    docker compose --env-file "$ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml up --build -d
    ;;
  logs)
    docker compose --env-file "$ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml logs -f
    ;;
  status)
    docker compose --env-file "$ENV_FILE" -f docker-compose.yml -f docker-compose.prod.yml ps
    ;;
  *)
    echo "Usage: $0 [env-file] {up|down|restart|logs|status}"
    exit 1
    ;;
esac
