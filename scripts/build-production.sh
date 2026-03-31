#!/usr/bin/env bash
# Build production artifacts for backend and frontend

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/sevacare-backend"
FRONTEND_DIR="$PROJECT_ROOT/sevacare-frontend"

API_BASE_URL="${EXPO_PUBLIC_API_BASE_URL:-https://api.sevacare.example.com/api/v1}"

echo "[1/2] Building backend (production jar)"
cd "$BACKEND_DIR"
mvn -pl sevacare-api -am -DskipTests clean package

echo "[2/2] Building frontend (production web export)"
cd "$FRONTEND_DIR"
EXPO_PUBLIC_API_BASE_URL="$API_BASE_URL" npx expo export --platform web

echo "Build complete"
echo "Backend artifact: $BACKEND_DIR/sevacare-api/target/sevacare-api-0.0.1-SNAPSHOT.jar"
echo "Frontend artifact: $FRONTEND_DIR/dist"
