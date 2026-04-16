#!/bin/bash
# End-to-end smoke test: inserts a log line and queries it back within a timeout.
# Exits 0 and returns JSON with passed:true on success, exits 1 with passed:false on failure.

set -euo pipefail

PORT="${PT_port:-9428}"
TIMEOUT="${PT_timeout:-15}"

INSERT_URL="http://localhost:${PORT}/insert/elasticsearch/_bulk"
QUERY_URL="http://localhost:${PORT}/select/logsql/query"

MARKER="bolt-smoke-test-$$-$(date -u +%s)"

fail() {
  echo "{\"passed\": false, \"message\": \"$1\"}"
  exit 1
}

# Verify curl is available
if ! command -v curl &>/dev/null; then
  fail "curl is not available on this host"
fi

# Verify the health endpoint is up before attempting insert
HTTP_STATUS=$(curl -so /dev/null -w "%{http_code}" --connect-timeout 5 \
  "http://localhost:${PORT}/health" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" != "200" ]; then
  fail "Health endpoint returned ${HTTP_STATUS}; VictoriaLogs may not be running on port ${PORT}"
fi

# Build the Elasticsearch bulk payload (two lines: action + document)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PAYLOAD="{\"index\":{}}"$'\n'"{\"_msg\":\"${MARKER}\",\"_time\":\"${TIMESTAMP}\",\"source\":\"bolt-smoke-test\"}"$'\n'

# Insert
INSERT_RESP=$(curl -sf -X POST "$INSERT_URL" \
  -H 'Content-Type: application/json' \
  --data-raw "$PAYLOAD" 2>/dev/null) || fail "Insert request failed"

INSERT_ERRORS=$(echo "$INSERT_RESP" | grep -o '"errors":[^,}]*' | grep -o '[^:]*$' | tr -d ' "' || echo "")
if [ "$INSERT_ERRORS" = "true" ]; then
  fail "Bulk insert reported errors: ${INSERT_RESP}"
fi

# Poll for the log entry (VictoriaLogs indexes asynchronously)
FOUND=false
DEADLINE=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  QUERY_RESP=$(curl -sf -G "$QUERY_URL" \
    --data-urlencode "query=_msg:\"${MARKER}\"" \
    --data-urlencode "start=5m" 2>/dev/null) || true

  if echo "$QUERY_RESP" | grep -qF "$MARKER"; then
    FOUND=true
    break
  fi
  sleep 1
done

if ! $FOUND; then
  fail "Inserted log line not found after ${TIMEOUT}s (marker: ${MARKER})"
fi

echo "{\"passed\": true, \"message\": \"Insert and query round-trip succeeded (marker: ${MARKER})\"}"
