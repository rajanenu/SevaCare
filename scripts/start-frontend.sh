#!/usr/bin/env bash
# Build and serve the Flutter web frontend (replaces old Expo/React Native web)
# Usage: ./scripts/start-frontend.sh [port]
# Example: ./scripts/start-frontend.sh 8087

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_DIR="$SCRIPT_DIR/../sevacare-flutter"
PORT="${1:-8087}"
BUILD_OUT="/tmp/sevacare-web"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║               Flutter Web — SevaCare Frontend                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

# Kill any existing server on the target port
if lsof -ti tcp:"$PORT" &>/dev/null; then
  echo "⚠  Killing existing process on port $PORT..."
  kill "$(lsof -ti tcp:"$PORT")" 2>/dev/null || true
fi

# Build Flutter web
echo "🔨 Building Flutter web (release)..."
cd "$FLUTTER_DIR"
flutter build web --release --output="$BUILD_OUT" || {
  echo "❌ Build failed"
  exit 1
}
echo "✅ Build complete → $BUILD_OUT"

# Serve
echo "🚀 Starting server on port $PORT..."
python3 -m http.server "$PORT" --directory "$BUILD_OUT" &
SERVER_PID=$!

sleep 1
if ! curl -sf "http://localhost:$PORT/" -o /dev/null; then
  echo "❌ Server failed to start"
  exit 1
fi

# Detect LAN IP
LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)

echo ""
echo "✅ Frontend is running"
echo ""
echo "   Local   → http://localhost:$PORT"
[ -n "$LAN_IP" ] && echo "   Network → http://$LAN_IP:$PORT"
echo ""
echo "⏹  Stop: kill $SERVER_PID  (or Ctrl+C)"

wait $SERVER_PID
