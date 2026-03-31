#!/usr/bin/env bash
# SevaCare API Test Script (Doctor + Admin + Patient critical flows)
# Usage: bash scripts/test-all-apis.sh

set -u

BASE="${BASE_URL:-http://localhost:8081}"
TENANT="${TENANT_ID:-T-1001}"
DOCTOR_ID="${DOCTOR_ID:-D-1001}"
PATIENT_ID="${PATIENT_ID:-P-1001}"
DOCTOR_MOBILE="${DOCTOR_MOBILE:-9100000001}"
PATIENT_MOBILE="${PATIENT_MOBILE:-9000000001}"
ADMIN_MOBILE="${ADMIN_MOBILE:-9000000003}"
OTP="${OTP:-0000}"

PASS=0
FAIL=0
TOTAL=0
TMP_BODY="/tmp/sevacare_api_test_body.json"

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
    echo "  OK  $label (HTTP $actual_status)"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL $label (expected $expected_status, got $actual_status)"
    echo "       Response: $(echo "$body" | head -c 220)"
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

extract_token() {
  local role="$1"
  local mobile="$2"
  curl -s -X POST "$BASE/api/v1/auth/otp/verify" \
    -H "Content-Type: application/json" \
    -d "{\"tenantPublicId\":\"$TENANT\",\"role\":\"$role\",\"mobileNumber\":\"$mobile\",\"otp\":\"$OTP\"}" \
    | python3 -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('token', ''))" 2>/dev/null
}

echo ""
echo "============================================="
echo " SevaCare API Smoke Suite"
echo " BASE=$BASE TENANT=$TENANT"
echo "============================================="
echo ""

echo "AUTH"
expect "OTP request (doctor)" "200" "POST" "$BASE/api/v1/auth/otp/request" "" "" "{\"tenantPublicId\":\"$TENANT\",\"role\":\"doctor\",\"mobileNumber\":\"$DOCTOR_MOBILE\"}"

DT=$(extract_token "doctor" "$DOCTOR_MOBILE")
PT=$(extract_token "patient" "$PATIENT_MOBILE")
AT=$(extract_token "admin" "$ADMIN_MOBILE")

if [ -z "$DT" ]; then
  echo "  FAIL Could not obtain doctor token"
  FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1))
fi
if [ -z "$PT" ]; then
  echo "  FAIL Could not obtain patient token"
  FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1))
fi
if [ -z "$AT" ]; then
  echo "  FAIL Could not obtain admin token"
  FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1))
fi

echo ""
echo "PUBLIC"
expect "Health" "200" "GET" "$BASE/actuator/health" "" "" ""
expect "List tenants" "200" "GET" "$BASE/api/v1/public/tenants" "" "" ""
expect "Lookups" "200" "GET" "$BASE/api/v1/public/lookups" "" "" ""

echo ""
echo "DOCTOR + ADMIN CRITICAL"
if [ -n "$AT" ]; then
  expect "Doctor next public ID" "200" "GET" "$BASE/api/v1/doctors/$TENANT/records/next-public-id" "$AT" "$TENANT" ""

  NEXT_ID=$(curl -s -X GET "$BASE/api/v1/doctors/$TENANT/records/next-public-id" \
    -H "Authorization: Bearer $AT" -H "X-Tenant-Id: $TENANT" \
    | python3 -c "import sys, json; print(json.load(sys.stdin).get('data', ''))" 2>/dev/null)

  if [ -n "$NEXT_ID" ]; then
    expect "Doctor create (auto ID)" "200" "POST" "$BASE/api/v1/doctors/$TENANT/records" "$AT" "$TENANT" "{\"fullName\":\"Dr. Admin Flow\",\"specialty\":\"General Physician\",\"availability\":\"Mon-Fri 10 AM - 6 PM\",\"fee\":\"₹500\",\"active\":true,\"age\":38,\"address\":\"Admin Street, Hyderabad\",\"aboutMe\":\"Test profile\"}"
    expect "Doctor update (existing)" "200" "PUT" "$BASE/api/v1/doctors/$TENANT/records/$NEXT_ID" "$AT" "$TENANT" "{\"fullName\":\"Dr. Admin Flow Updated\",\"specialty\":\"General Physician\",\"availability\":\"Mon-Sat 9 AM - 5 PM\",\"fee\":\"₹550\",\"active\":true,\"age\":39,\"address\":\"Updated Address\",\"aboutMe\":\"Updated profile\"}"
    expect "Doctor delete" "200" "DELETE" "$BASE/api/v1/doctors/$TENANT/records/$NEXT_ID" "$AT" "$TENANT" ""
  fi

  expect "List doctor records" "200" "GET" "$BASE/api/v1/doctors/$TENANT/records" "$AT" "$TENANT" ""
  expect "Get doctor record" "200" "GET" "$BASE/api/v1/doctors/$TENANT/records/$DOCTOR_ID" "$AT" "$TENANT" ""
  expect "Admin overview" "200" "GET" "$BASE/api/v1/admin/$TENANT/overview" "$AT" "$TENANT" ""
fi

echo ""
echo "DOCTOR WORKFLOW"
if [ -n "$DT" ]; then
  expect "Doctor dashboard" "200" "GET" "$BASE/api/v1/doctors/$TENANT/$DOCTOR_ID/dashboard" "$DT" "$TENANT" ""
  expect "Doctor queue" "200" "GET" "$BASE/api/v1/doctors/$TENANT/$DOCTOR_ID/queue?date=$(date +%F)" "$DT" "$TENANT" ""
  expect "Doctor patient list" "200" "GET" "$BASE/api/v1/doctors/$TENANT/$DOCTOR_ID/patients" "$DT" "$TENANT" ""
  expect "Doctor prescription list" "200" "GET" "$BASE/api/v1/doctors/$TENANT/$DOCTOR_ID/prescriptions/list" "$DT" "$TENANT" ""

  expect "Upload prescription" "200" "POST" "$BASE/api/v1/doctors/$TENANT/$DOCTOR_ID/prescriptions" "$DT" "$TENANT" "{\"patientPublicId\":\"$PATIENT_ID\",\"doctorPublicId\":\"$DOCTOR_ID\",\"doctorName\":\"Dr. Meera Rao\",\"medicines\":[{\"medicineName\":\"Paracetamol\",\"strength\":\"500 mg\",\"frequency\":\"Twice daily\",\"duration\":\"3 days\",\"instructions\":\"After food\"}],\"notes\":\"API test\"}"
fi

echo ""
echo "PATIENT WORKFLOW"
if [ -n "$PT" ]; then
  expect "Patient home" "200" "GET" "$BASE/api/v1/patients/$TENANT/$PATIENT_ID/home" "$PT" "$TENANT" ""
  expect "Booking setup" "200" "GET" "$BASE/api/v1/patients/$TENANT/$PATIENT_ID/booking/setup" "$PT" "$TENANT" ""
  expect "Patient records get" "200" "GET" "$BASE/api/v1/patients/$TENANT/records/$PATIENT_ID" "$PT" "$TENANT" ""
  expect "Patient prescriptions" "200" "GET" "$BASE/api/v1/patients/$TENANT/$PATIENT_ID/prescriptions" "$PT" "$TENANT" ""
  expect "Patient medical history" "200" "GET" "$BASE/api/v1/patients/$TENANT/$PATIENT_ID/medical-history" "$PT" "$TENANT" ""
fi

echo ""
echo "ACCESS CONTROL"
if [ -n "$PT" ]; then
  expect "Patient cannot admin overview" "403" "GET" "$BASE/api/v1/admin/$TENANT/overview" "$PT" "$TENANT" ""
fi

echo ""
echo "============================================="
echo "RESULTS: $PASS passed / $FAIL failed / $TOTAL total"
echo "============================================="
echo ""

exit $FAIL
