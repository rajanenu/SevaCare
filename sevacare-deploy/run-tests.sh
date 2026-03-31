#!/usr/bin/env bash
# ───────────────────────────────────────────────
# SevaCare – Run E2E Tests
# Requires backend (8081) and frontend (8087) running
# ───────────────────────────────────────────────
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
E2E_DIR="$ROOT_DIR/sevacare-e2e-test"

echo "═══ SevaCare E2E Tests ═══"

# Check backend
echo "→ Checking backend on port 8081..."
if ! curl -sf http://localhost:8081/api/v1/public/tenants > /dev/null 2>&1; then
  echo "  ✗ Backend not running on port 8081"
  exit 1
fi
echo "  ✓ Backend is ready"

# Check frontend
echo "→ Checking frontend on port 8087..."
if ! curl -sf http://localhost:8087 > /dev/null 2>&1; then
  echo "  ✗ Frontend not running on port 8087"
  exit 1
fi
echo "  ✓ Frontend is ready"

# Run tests
cd "$E2E_DIR"

SUITE="${1:-all}"

case "$SUITE" in
  smoke)     npx playwright test tests/smoke.spec.ts ;;
  onboarding) npx playwright test tests/onboarding.spec.ts ;;
  patient)   npx playwright test tests/patient.spec.ts ;;
  doctor)    npx playwright test tests/doctor.spec.ts ;;
  admin)     npx playwright test tests/admin.spec.ts ;;
  api)       npx playwright test tests/api.spec.ts ;;
  lifecycle) npx playwright test tests/lifecycle.spec.ts ;;
  all)       npx playwright test tests/onboarding.spec.ts tests/patient.spec.ts tests/doctor.spec.ts tests/admin.spec.ts tests/api.spec.ts tests/lifecycle.spec.ts ;;
  *)
    echo "Usage: $0 {smoke|onboarding|patient|doctor|admin|api|lifecycle|all}"
    exit 1
    ;;
esac

echo ""
echo "═══ Test run complete ═══"
echo "View report: cd $E2E_DIR && npx playwright show-report"
