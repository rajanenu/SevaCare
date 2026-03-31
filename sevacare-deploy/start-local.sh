#!/usr/bin/env bash
# ───────────────────────────────────────────────
# SevaCare – Local Development Start Script
# Starts PostgreSQL (assumes local), backend, and frontend
# ───────────────────────────────────────────────
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/sevacare-backend"
FRONTEND_DIR="$ROOT_DIR/sevacare-frontend"

echo "═══ SevaCare Local Dev ═══"

# ── 1. Check PostgreSQL ────
echo "→ Checking PostgreSQL on port 5432..."
if ! pg_isready -h localhost -p 5432 -q 2>/dev/null; then
  echo "  ✗ PostgreSQL not running. Please start it first."
  exit 1
fi
echo "  ✓ PostgreSQL is ready"

# ── 2. Build & start backend ────
echo "→ Building backend..."
cd "$BACKEND_DIR"
./mvnw -pl sevacare-api -am -DskipTests clean package -q

echo "→ Starting backend on port 8081..."
java -jar sevacare-api/target/*.jar \
  --server.port=8081 \
  --spring.datasource.url=jdbc:postgresql://localhost:5432/seva_care \
  --spring.datasource.username=postgres \
  --spring.datasource.password=postgres &
BACKEND_PID=$!
echo "  Backend PID: $BACKEND_PID"

# Wait for backend readiness
echo "→ Waiting for backend..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:8081/api/v1/public/tenants > /dev/null 2>&1; then
    echo "  ✓ Backend ready"
    break
  fi
  sleep 2
done

# ── 3. Build & serve frontend ────
echo "→ Building frontend..."
cd "$FRONTEND_DIR"
EXPO_PUBLIC_API_BASE_URL=http://localhost:8081/api/v1 npx expo export --platform web

echo "→ Serving frontend on port 8087..."
npx serve -s dist -l 8087 &
FRONTEND_PID=$!
echo "  Frontend PID: $FRONTEND_PID"

echo ""
echo "═══ SevaCare is running ═══"
echo "  Frontend: http://localhost:8087"
echo "  Backend:  http://localhost:8081"
echo ""
echo "Press Ctrl+C to stop all services"

# Cleanup on exit
trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null" EXIT INT TERM
wait
