#!/bin/bash
###############################################################################
# simulate-logs.sh
# Runs all curl commands from docs/TESTING.md to simulate log generation.
#
# Usage:
#   ./scripts/simulate-logs.sh              # Run against Azure
#   ./scripts/simulate-logs.sh --local      # Run against local dev server
#   ./scripts/simulate-logs.sh --base-url <url>  # Custom base URL
###############################################################################

set -euo pipefail

# --- Configuration ---
DEFAULT_BASE_URL="https://func-funclogging.azurewebsites.net/api"
LOCAL_BASE_URL="http://localhost:7071/api"
DELAY_BETWEEN_REQUESTS=1  # seconds between requests

# --- Parse arguments ---
BASE_URL="$DEFAULT_BASE_URL"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)
      BASE_URL="$LOCAL_BASE_URL"
      shift
      ;;
    --base-url)
      BASE_URL="$2"
      shift 2
      ;;
    --no-delay)
      DELAY_BETWEEN_REQUESTS=0
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--local] [--base-url <url>] [--no-delay]"
      echo ""
      echo "Options:"
      echo "  --local       Use http://localhost:7071/api"
      echo "  --base-url    Specify a custom base URL"
      echo "  --no-delay    Don't pause between requests"
      echo "  -h, --help    Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# --- Helpers ---
PASS=0
FAIL=0
TOTAL=0

run() {
  local description="$1"
  shift
  TOTAL=$((TOTAL + 1))
  echo ""
  echo "──────────────────────────────────────────────────────────────"
  echo "[$TOTAL] $description"
  echo "──────────────────────────────────────────────────────────────"

  local http_code
  local body
  body=$(mktemp)

  set +e
  http_code=$(curl -s -o "$body" -w "%{http_code}" "$@")
  local exit_code=$?
  set -e

  if [[ $exit_code -ne 0 ]]; then
    echo "  ❌ CURL FAILED (exit code $exit_code)"
    FAIL=$((FAIL + 1))
  elif [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo "  ✅ HTTP $http_code"
    PASS=$((PASS + 1))
  else
    echo "  ⚠️  HTTP $http_code"
    FAIL=$((FAIL + 1))
  fi

  # Print response body (truncated if large)
  local size
  size=$(wc -c < "$body")
  if [[ $size -gt 0 ]]; then
    if [[ $size -le 1000 ]]; then
      echo "  Response: $(cat "$body")"
    else
      echo "  Response (truncated): $(head -c 1000 "$body")..."
    fi
  fi

  rm -f "$body"
  [[ $DELAY_BETWEEN_REQUESTS -gt 0 ]] && sleep "$DELAY_BETWEEN_REQUESTS"
}

# --- Banner ---
echo "============================================================"
echo "  Azure Functions Logging Simulation"
echo "  Base URL: $BASE_URL"
echo "  Started:  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================================"

###############################################################################
# 1. Health & Basic Endpoints
###############################################################################
echo ""
echo "===== SECTION 1: Health & Basic Endpoints ====="

run "Health Check" \
  "$BASE_URL/healthcheck"

run "HTTP GET - Simple greeting" \
  "$BASE_URL/httpget?name=TestUser"

run "HTTP GET - Debug log level" \
  "$BASE_URL/httpget?name=DebugTest&loglevel=debug"

run "HTTP GET - Warning log level" \
  "$BASE_URL/httpget?name=WarningTest&loglevel=warning"

run "HTTP GET - Error log level" \
  "$BASE_URL/httpget?name=ErrorTest&loglevel=error"

run "Logging Demo - Shows all log levels" \
  "$BASE_URL/loggingdemo"

###############################################################################
# 2. POST Endpoints
###############################################################################
echo ""
echo "===== SECTION 2: POST Endpoints ====="

run "HTTP POST - Basic (5 logs)" \
  -X POST "$BASE_URL/httppost" \
  -H "Content-Type: application/json" \
  -d '{"name": "TestUser", "generateLogs": 5, "simulateError": false}'

run "HTTP POST - Generate many logs (50)" \
  -X POST "$BASE_URL/httppost" \
  -H "Content-Type: application/json" \
  -d '{"name": "LoadTest", "generateLogs": 50, "simulateError": false}'

run "HTTP POST - Simulate error" \
  -X POST "$BASE_URL/httppost" \
  -H "Content-Type: application/json" \
  -d '{"name": "ErrorTest", "generateLogs": 1, "simulateError": true}'

###############################################################################
# 3. Performance & Sampling Tests
###############################################################################
echo ""
echo "===== SECTION 3: Performance & Sampling Tests ====="

run "Performance Test - Default" \
  "$BASE_URL/performancetest"

run "Performance Test - High frequency (1000 iterations, log every 10)" \
  "$BASE_URL/performancetest?iterations=1000&logfrequency=10"

run "Sampling Test - 50 entries" \
  "$BASE_URL/samplingtest?count=50"

run "Sampling Test - 100 entries" \
  "$BASE_URL/samplingtest?count=100"

###############################################################################
# 4. Queue Operations
###############################################################################
echo ""
echo "===== SECTION 4: Queue Operations ====="

run "Send single message to queue" \
  -X POST "$BASE_URL/queuemessage" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from logging demo!", "count": 1, "includeMetadata": true}'

run "Send 5 messages to queue" \
  -X POST "$BASE_URL/queuemessage" \
  -H "Content-Type: application/json" \
  -d '{"message": "Test message", "count": 5, "includeMetadata": true}'

run "Send 50 messages to queue (sampling observation)" \
  -X POST "$BASE_URL/queuemessage" \
  -H "Content-Type: application/json" \
  -d '{"message": "Bulk sampling test", "count": 50, "includeMetadata": true}'

run "Send 100 messages to queue (maximum per request)" \
  -X POST "$BASE_URL/queuemessage" \
  -H "Content-Type: application/json" \
  -d '{"message": "Load test message", "count": 100, "includeMetadata": false}'

run "Check queue status" \
  "$BASE_URL/queuestatus"

run "Clear all messages from queue" \
  -X DELETE "$BASE_URL/queueclear"

###############################################################################
# Summary
###############################################################################
echo ""
echo "============================================================"
echo "  Simulation Complete"
echo "  Finished: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "------------------------------------------------------------"
echo "  Total:  $TOTAL"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "============================================================"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
