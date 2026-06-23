#!/usr/bin/env bash

set -u

BASE_URL="${BASE_URL:-http://localhost:8081}"
TENANT_ID="${TENANT_ID:-}"
ADMIN_MOBILE="${ADMIN_MOBILE:-9000000003}"
OTP="${OTP:-0000}"
RUN_ID="$(date +%s)"
CREATE_EMAIL="integration.admin.${RUN_ID}@sevacare.test"
UPDATE_EMAIL="updated.integration.admin.${RUN_ID}@sevacare.test"

PASS=0
FAIL=0
TOTAL=0
TMP_BODY="/tmp/sevacare_admin_api_test_body.json"
AUTH_TOKEN=""
CREATED_ADMIN_ID=""

cleanup() {
    rm -f "$TMP_BODY"
}
trap cleanup EXIT

check() {
    local label="$1"
    local expected_status="$2"
    local actual_status="$3"
    local body="$4"
    TOTAL=$((TOTAL + 1))
    if [ "$actual_status" = "$expected_status" ]; then
        PASS=$((PASS + 1))
        echo "  OK   $label (HTTP $actual_status)"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL $label (expected $expected_status, got $actual_status)"
        echo "       Response: $(echo "$body" | head -c 260)"
    fi
}

call_api() {
    local method="$1"
    local url="$2"
    local token="$3"
    local tenant="$4"
    local data="$5"

    local args=(-s -o "$TMP_BODY" -w "%{http_code}" -X "$method")
    if [ -n "$token" ]; then
        args+=(-H "Authorization: Bearer $token")
    fi
    if [ -n "$tenant" ]; then
        args+=(-H "X-Tenant-Id: $tenant")
    fi
    if [ -n "$data" ]; then
        args+=(-H "Content-Type: application/json" -d "$data")
    fi
    args+=("$url")
    curl "${args[@]}"
}

expect() {
    local label="$1"
    local expected="$2"
    local method="$3"
    local url="$4"
    local token="$5"
    local tenant="$6"
    local data="$7"

    local status
    status=$(call_api "$method" "$url" "$token" "$tenant" "$data")
    local body
    body=$(cat "$TMP_BODY")
    check "$label" "$expected" "$status" "$body"
}

extract_json() {
    local expression="$1"
    python3 -c "import sys, json; data=json.load(sys.stdin); print($expression)" 2>/dev/null
}

echo ""
echo "============================================="
echo " Admin User API Test Suite"
echo "============================================="
echo ""

if [ -z "$TENANT_ID" ]; then
    TENANT_ID=$(curl -s "$BASE_URL/api/v1/public/tenants" | extract_json "(data.get('data', {}) or {}).get('tenants', [{}])[0].get('tenantPublicId', '')")
fi

if [ -z "$TENANT_ID" ]; then
    echo "  FAIL Could not discover an active tenant id"
    exit 1
fi

echo " Using tenant: $TENANT_ID"

expect "Health" "200" "GET" "$BASE_URL/actuator/health" "" "" ""
expect "OTP request (admin)" "200" "POST" "$BASE_URL/api/v1/auth/otp/request" "" "" "{\"tenantPublicId\":\"$TENANT_ID\",\"role\":\"admin\",\"mobileNumber\":\"$ADMIN_MOBILE\"}"

AUTH_TOKEN=$(curl -s -X POST "$BASE_URL/api/v1/auth/otp/verify" \
    -H "Content-Type: application/json" \
    -d "{\"tenantPublicId\":\"$TENANT_ID\",\"role\":\"admin\",\"mobileNumber\":\"$ADMIN_MOBILE\",\"otp\":\"$OTP\"}" \
    | extract_json "data.get('data', {}).get('token', '')")

if [ -z "$AUTH_TOKEN" ]; then
    TOTAL=$((TOTAL + 1))
    FAIL=$((FAIL + 1))
    echo "  FAIL Could not obtain admin auth token"
    exit 1
fi

expect "List admin users" "200" "GET" "$BASE_URL/api/v1/admin/$TENANT_ID/users" "$AUTH_TOKEN" "$TENANT_ID" ""
expect "Next admin public ID" "200" "GET" "$BASE_URL/api/v1/admin/$TENANT_ID/users/next-public-id" "$AUTH_TOKEN" "$TENANT_ID" ""

CREATE_PAYLOAD="{\"fullName\":\"Integration Admin\",\"name\":\"Integration Admin\",\"email\":\"$CREATE_EMAIL\",\"mobileNumber\":\"9000000099\",\"active\":true}"
CREATE_STATUS=$(call_api "POST" "$BASE_URL/api/v1/admin/$TENANT_ID/users" "$AUTH_TOKEN" "$TENANT_ID" "$CREATE_PAYLOAD")
CREATE_BODY=$(cat "$TMP_BODY")
check "Create admin user" "200" "$CREATE_STATUS" "$CREATE_BODY"

CREATED_ADMIN_ID=$(printf '%s' "$CREATE_BODY" | extract_json "data.get('data', {}).get('adminPublicId', '')")

if [ -n "$CREATED_ADMIN_ID" ]; then
    expect "Get admin user" "200" "GET" "$BASE_URL/api/v1/admin/$TENANT_ID/users/$CREATED_ADMIN_ID" "$AUTH_TOKEN" "$TENANT_ID" ""
    expect "List active admin users" "200" "GET" "$BASE_URL/api/v1/admin/$TENANT_ID/users?activeOnly=true" "$AUTH_TOKEN" "$TENANT_ID" ""
    expect "Update admin user" "200" "PUT" "$BASE_URL/api/v1/admin/$TENANT_ID/users/$CREATED_ADMIN_ID" "$AUTH_TOKEN" "$TENANT_ID" "{\"fullName\":\"Updated Integration Admin\",\"name\":\"Updated Admin\",\"email\":\"$UPDATE_EMAIL\",\"mobileNumber\":\"9000000100\",\"active\":true}"
    expect "Deactivate admin user" "200" "PUT" "$BASE_URL/api/v1/admin/$TENANT_ID/users/$CREATED_ADMIN_ID/deactivate" "$AUTH_TOKEN" "$TENANT_ID" ""
    expect "Get deactivated admin user" "200" "GET" "$BASE_URL/api/v1/admin/$TENANT_ID/users/$CREATED_ADMIN_ID" "$AUTH_TOKEN" "$TENANT_ID" ""
    expect "Delete admin user" "200" "DELETE" "$BASE_URL/api/v1/admin/$TENANT_ID/users/$CREATED_ADMIN_ID" "$AUTH_TOKEN" "$TENANT_ID" ""
else
    TOTAL=$((TOTAL + 2))
    FAIL=$((FAIL + 2))
    echo "  FAIL Could not extract created admin id"
fi

expect "Admin overview" "200" "GET" "$BASE_URL/api/v1/admin/$TENANT_ID/overview" "$AUTH_TOKEN" "$TENANT_ID" ""
expect "Missing tenant header is rejected" "403" "GET" "$BASE_URL/api/v1/admin/$TENANT_ID/users" "$AUTH_TOKEN" "" ""

echo ""
echo "============================================="
echo " RESULTS: $PASS passed / $FAIL failed / $TOTAL total"
echo "============================================="
echo ""

exit $FAIL
