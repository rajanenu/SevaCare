#!/usr/bin/env bash
set -u

BASE_URL="${BASE_URL:-http://localhost:8081}"
PLATFORM_MOBILE="${PLATFORM_MOBILE:-9000000999}"
OTP="${OTP:-0000}"
RUN_ID="$(date +%s)"
TMP_BODY="/tmp/sevacare_platform_admin_api_test_body.json"
PASS=0
FAIL=0
TOTAL=0
TOKEN=""
CREATED_ID=""

cleanup() {
  rm -f "$TMP_BODY"
}
trap cleanup EXIT

check() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  local body="$4"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  OK   $label (HTTP $actual)"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL $label (expected $expected, got $actual)"
    echo "       Response: $(echo "$body" | head -c 260)"
  fi
}

call_api() {
  local method="$1"
  local url="$2"
  local token="$3"
  local data="$4"

  local args=(-s -o "$TMP_BODY" -w "%{http_code}" -X "$method")
  if [ -n "$token" ]; then
    args+=(-H "Authorization: Bearer $token")
  fi
  if [ -n "$data" ]; then
    args+=(-H "Content-Type: application/json" -d "$data")
  fi
  args+=("$url")

  curl "${args[@]}"
}

extract_json() {
  local expression="$1"
  python3 -c "import sys, json; payload=json.load(sys.stdin); print($expression)" 2>/dev/null
}

echo ""
echo "============================================="
echo " Platform Admin CRUD API Test Suite"
echo "============================================="
echo ""

status=$(call_api "GET" "$BASE_URL/actuator/health" "" "")
check "Health" "200" "$status" "$(cat "$TMP_BODY")"

status=$(call_api "POST" "$BASE_URL/api/v1/auth/otp/request" "" '{"tenantPublicId":"platform","role":"platform_admin","mobileNumber":"'"$PLATFORM_MOBILE"'"}')
check "OTP request (platform_admin)" "200" "$status" "$(cat "$TMP_BODY")"

TOKEN=$(curl -s -X POST "$BASE_URL/api/v1/auth/otp/verify" \
  -H "Content-Type: application/json" \
  -d '{"tenantPublicId":"platform","role":"platform_admin","mobileNumber":"'"$PLATFORM_MOBILE"'","otp":"'"$OTP"'"}' \
  | extract_json "payload.get('data', {}).get('token', '')")

if [ -z "$TOKEN" ]; then
  TOTAL=$((TOTAL + 1))
  FAIL=$((FAIL + 1))
  echo "  FAIL Could not obtain platform admin token"
  echo ""
  echo "RESULTS: $PASS passed / $FAIL failed / $TOTAL total"
  exit 1
fi

status=$(call_api "GET" "$BASE_URL/api/v1/platform-admin/overview" "$TOKEN" "")
check "Platform overview" "200" "$status" "$(cat "$TMP_BODY")"

status=$(call_api "GET" "$BASE_URL/api/v1/platform-admin/users" "$TOKEN" "")
check "Platform users getAll" "200" "$status" "$(cat "$TMP_BODY")"

status=$(call_api "GET" "$BASE_URL/api/v1/platform-admin/users/next-public-id" "$TOKEN" "")
check "Platform users next ID" "200" "$status" "$(cat "$TMP_BODY")"

CREATE_EMAIL="platform.integration.$RUN_ID@sevacare.test"
CREATE_PAYLOAD='{"fullName":"Platform Integration User","mobileNumber":"9000011111","email":"'"$CREATE_EMAIL"'","active":true}'
status=$(call_api "POST" "$BASE_URL/api/v1/platform-admin/users" "$TOKEN" "$CREATE_PAYLOAD")
body=$(cat "$TMP_BODY")
check "Platform users create" "200" "$status" "$body"
CREATED_ID=$(printf '%s' "$body" | extract_json "payload.get('data', {}).get('platformAdminPublicId', '')")

if [ -n "$CREATED_ID" ]; then
  status=$(call_api "GET" "$BASE_URL/api/v1/platform-admin/users/$CREATED_ID" "$TOKEN" "")
  check "Platform users get" "200" "$status" "$(cat "$TMP_BODY")"

  UPDATE_PAYLOAD='{"fullName":"Platform Integration User Updated","mobileNumber":"9000011112","email":"updated.'"$RUN_ID"'@sevacare.test","active":true}'
  status=$(call_api "PUT" "$BASE_URL/api/v1/platform-admin/users/$CREATED_ID" "$TOKEN" "$UPDATE_PAYLOAD")
  check "Platform users update" "200" "$status" "$(cat "$TMP_BODY")"

  status=$(call_api "PUT" "$BASE_URL/api/v1/platform-admin/users/$CREATED_ID/deactivate" "$TOKEN" "")
  check "Platform users deactivate" "200" "$status" "$(cat "$TMP_BODY")"

  status=$(call_api "DELETE" "$BASE_URL/api/v1/platform-admin/users/$CREATED_ID" "$TOKEN" "")
  check "Platform users delete" "200" "$status" "$(cat "$TMP_BODY")"
else
  TOTAL=$((TOTAL + 4))
  FAIL=$((FAIL + 4))
  echo "  FAIL Could not extract created platform admin ID"
fi

echo ""
echo "============================================="
echo " RESULTS: $PASS passed / $FAIL failed / $TOTAL total"
echo "============================================="
echo ""

exit $FAIL
