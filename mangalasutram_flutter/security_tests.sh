#!/bin/bash
# ============================================================
# MANGALASUTRAM — Security Test Suite (Edge Function based)
# Run: bash security_tests.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
fi

if [ -z "$SUPABASE_URL" ]; then
    echo "ERROR: Set SUPABASE_URL or add to .env"
    exit 1
fi
if [ -z "$SUPABASE_ANON_KEY" ] && [ -z "$SUPABASE_PUBLISHABLE_KEY" ]; then
    echo "ERROR: Set SUPABASE_ANON_KEY or SUPABASE_PUBLISHABLE_KEY in .env"
    exit 1
fi
if [ -z "$TEST_EMAIL" ]; then
    echo "ERROR: Set TEST_EMAIL or add to .env"
    exit 1
fi
if [ -z "$STRONG_PASSWORD" ]; then
    echo "ERROR: Set STRONG_PASSWORD or add to .env"
    exit 1
fi

# Support both variable names
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$SUPABASE_PUBLISHABLE_KEY}"

NONEXISTENT_EMAIL="test-nonexist-$(date +%s)@test.com"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

function test_header() {
    echo ""
    echo "========================================"
    echo "  $1"
    echo "========================================"
}

function assert_equals() {
    local actual="$1"
    local expected="$2"
    local label="$3"

    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}[PASS]${NC} $label"
        ((PASS++))
    else
        echo -e "${RED}[FAIL]${NC} $label"
        echo "  Expected: $expected"
        echo "  Got:      $actual"
        ((FAIL++))
    fi
}

function assert_contains() {
    local body="$1"
    local needle="$2"
    local label="$3"
    local should_not_contain="${4:-false}"

    if [ "$should_not_contain" = "true" ]; then
        if echo "$body" | grep -qi "$needle"; then
            echo -e "${RED}[FAIL]${NC} $label"
            echo "  Body should NOT contain: $needle"
            echo "  Got: $body"
            ((FAIL++))
        else
            echo -e "${GREEN}[PASS]${NC} $label"
            ((PASS++))
        fi
    else
        if echo "$body" | grep -qi "$needle"; then
            echo -e "${GREEN}[PASS]${NC} $label"
            ((PASS++))
        else
            echo -e "${RED}[FAIL]${NC} $label"
            echo "  Expected body to contain: $needle"
            echo "  Got: $body"
            ((FAIL++))
        fi
    fi
}

# ============================================================
# TEST 1: Password Strength Rules (via edge function)
# ============================================================
test_header "TEST 1: Password Strength Rules (edge function)"

echo "--- Weak password (no uppercase, no special char) ---"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$SUPABASE_URL/functions/v1/signup" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"test-weak-$(date +%s)@test.com\",\"password\":\"password1\"}")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
assert_equals "$HTTP_CODE" "400" "Weak password rejected with 400"
assert_contains "$BODY" "password" "Error mentions password requirement"

echo ""
echo "--- Strong password (uppercase + special char) ---"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$SUPABASE_URL/functions/v1/signup" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"test-strong-$(date +%s)@test.com\",\"password\":\"$STRONG_PASSWORD\"}")
HTTP_CODE=$(echo "$RESP" | tail -1)
if [ "$HTTP_CODE" != "400" ]; then
    echo -e "${GREEN}[PASS]${NC} Strong password accepted (not rejected as weak)"
    ((PASS++))
else
    echo -e "${RED}[FAIL]${NC} Strong password was rejected"
    ((FAIL++))
fi

# ============================================================
# TEST 2: Account Enumeration (via edge function)
# ============================================================
test_header "TEST 2: Account Enumeration (edge function masks errors)"

echo "--- Signup with EXISTING email ($TEST_EMAIL) ---"
RESP1=$(curl -s -w "\n%{http_code}" -X POST "$SUPABASE_URL/functions/v1/signup" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$STRONG_PASSWORD\"}")
HTTP1=$(echo "$RESP1" | tail -1)
BODY1=$(echo "$RESP1" | sed '$d')

echo "--- Signup with NONEXISTENT email ---"
RESP2=$(curl -s -w "\n%{http_code}" -X POST "$SUPABASE_URL/functions/v1/signup" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"test-nonexist-$(date +%s)@test.com\",\"password\":\"$STRONG_PASSWORD\"}")
HTTP2=$(echo "$RESP2" | tail -1)
BODY2=$(echo "$RESP2" | sed '$d')

if [ "$HTTP1" = "$HTTP2" ]; then
    echo -e "${GREEN}[PASS]${NC} Same status code for existing vs new email ($HTTP1)"
    ((PASS++))
else
    echo -e "${YELLOW}[WARN]${NC} Different status codes — existing: $HTTP1, new: $HTTP2"
fi

# Both responses should be generic — no "already registered" leak
assert_contains "$BODY1" "already registered" "Existing email doesn't leak via API" true
assert_contains "$BODY1" "already exists" "Existing email doesn't leak via API" true
assert_contains "$BODY2" "already registered" "New email response generic" true
assert_contains "$BODY2" "already exists" "New email response generic" true

echo ""
echo "--- Login with WRONG password for existing email ---"
RESP3=$(curl -s -w "\n%{http_code}" -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"WrongPass123!\"}")
HTTP3=$(echo "$RESP3" | tail -1)
BODY3=$(echo "$RESP3" | sed '$d')

echo "--- Login with WRONG password for nonexistent email ---"
RESP4=$(curl -s -w "\n%{http_code}" -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"test-nonexist-$(date +%s)@test.com\",\"password\":\"WrongPass123!\"}")
HTTP4=$(echo "$RESP4" | tail -1)
BODY4=$(echo "$RESP4" | sed '$d')

if [ "$HTTP3" = "$HTTP4" ]; then
    echo -e "${GREEN}[PASS]${NC} Same status code for wrong-password login ($HTTP3)"
    ((PASS++))
else
    echo -e "${YELLOW}[WARN]${NC} Different status codes — existing: $HTTP3, nonexistent: $HTTP4"
fi

assert_contains "$BODY3" "user not found" "Login doesn't reveal account" true
assert_contains "$BODY3" "no user" "Login doesn't reveal account" true
assert_contains "$BODY4" "user not found" "Login doesn't reveal nonexistent" true
assert_contains "$BODY4" "no user" "Login doesn't reveal nonexistent" true

# ============================================================
# TEST 3: OTP Rate Limiter (verify-otp)
# ============================================================
test_header "TEST 3: OTP Rate Limiter (verify-otp)"

echo -e "${YELLOW}WARNING: Creates DB records. Using: $TEST_EMAIL${NC}"
echo "Continuing in 3 seconds..."
sleep 3

EDGE_URL="$SUPABASE_URL/functions/v1/verify-otp"

echo ""
echo "--- 5 wrong OTPs (all should return 400) ---"
for i in 1 2 3 4 5; do
    RESP=$(curl -s -w "\n%{http_code}" -X POST "$EDGE_URL" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"$TEST_EMAIL\",\"code\":\"000000\",\"purpose\":\"reset_password\"}")
    HTTP=$(echo "$RESP" | tail -1)
    echo "  Attempt $i: HTTP $HTTP"
    if [ "$i" -eq 5 ]; then
        assert_equals "$HTTP" "400" "5th wrong OTP returns 400 (not yet blocked)"
    fi
done

echo ""
echo "--- 6th wrong OTP (should be BLOCKED with 429) ---"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$EDGE_URL" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"code\":\"000000\",\"purpose\":\"reset_password\"}")
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
assert_equals "$HTTP" "429" "6th wrong OTP blocked (429)"
assert_contains "$BODY" "Too many failed attempts" "Block message is clear"

# ============================================================
# TEST 4: OTP Send Rate Limiter (send-otp)
# ============================================================
test_header "TEST 4: OTP Send Rate Limiter (send-otp)"

echo -e "${YELLOW}WARNING: May block email/IP for 10 min.${NC}"
sleep 2

EDGE_URL="$SUPABASE_URL/functions/v1/send-otp"

echo ""
echo "--- 3 OTP requests (should all succeed with 200) ---"
for i in 1 2 3; do
    RESP=$(curl -s -w "\n%{http_code}" -X POST "$EDGE_URL" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"test-otp-send-$(date +%s)-$i@test.com\",\"purpose\":\"reset_password\"}")
    HTTP=$(echo "$RESP" | tail -1)
    echo "  Request $i: HTTP $HTTP"
    if [ "$i" -eq 3 ]; then
        assert_equals "$HTTP" "200" "3rd OTP request succeeds (200)"
    fi
done

echo ""
echo "--- 4th OTP request (same email, should be BLOCKED with 429) ---"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$EDGE_URL" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"test-otp-send-$(date +%s)@test.com\",\"purpose\":\"reset_password\"}")
HTTP=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')
assert_equals "$HTTP" "429" "4th request blocked (429)"
assert_contains "$BODY" "Too many OTP requests" "Block message is clear"

# ============================================================
# TEST 5: CORS Check
# ============================================================
test_header "TEST 5: CORS Configuration"

echo "--- Preflight from allowed origin ---"
RESP=$(curl -s -w "\n%{http_code}" -X OPTIONS "$SUPABASE_URL/functions/v1/send-otp" \
  -H "Origin: https://mangalsutram.me" \
  -H "Access-Control-Request-Method: POST")
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" = "204" ] || [ "$HTTP" = "200" ]; then
    echo -e "${GREEN}[PASS]${NC} Allowed origin gets CORS response (HTTP $HTTP)"
    ((PASS++))
else
    echo -e "${RED}[FAIL]${NC} Expected 204 or 200, got $HTTP"
    ((FAIL++))
fi

echo "--- Preflight from evil origin ---"
RESP=$(curl -s -w "\n%{http_code}" -X OPTIONS "$SUPABASE_URL/functions/v1/send-otp" \
  -H "Origin: https://evil-site.com" \
  -H "Access-Control-Request-Method: POST")
HTTP=$(echo "$RESP" | tail -1)
if [ "$HTTP" != "204" ] && [ "$HTTP" != "200" ]; then
    echo -e "${GREEN}[PASS]${NC} Evil origin blocked (HTTP $HTTP)"
    ((PASS++))
else
    echo -e "${RED}[FAIL]${NC} Evil origin was allowed (HTTP $HTTP)"
    ((FAIL++))
fi

# ============================================================
# RESULTS
# ============================================================
echo ""
echo "========================================"
echo "  RESULTS"
echo "========================================"
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Review output above.${NC}"
    exit 1
fi
