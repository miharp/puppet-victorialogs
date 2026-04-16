#!/bin/bash
# Checks systemctl service state and the VictoriaLogs HTTP /-/ready endpoint.

set -euo pipefail

SERVICE_NAME="${PT_service_name:-victorialogs-single}"
PORT="${PT_port:-9428}"

# Check systemd active state
ACTIVE=false
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
  ACTIVE=true
fi

# Check HTTP readiness endpoint
READY=false
HTTP_MSG=""
if command -v curl &>/dev/null; then
  HTTP_STATUS=$(curl -so /dev/null -w "%{http_code}" --connect-timeout 3 \
    "http://localhost:${PORT}/-/ready" 2>/dev/null || echo "000")
  if [ "$HTTP_STATUS" = "200" ]; then
    READY=true
    HTTP_MSG="HTTP /-/ready returned 200"
  else
    HTTP_MSG="HTTP /-/ready returned ${HTTP_STATUS}"
  fi
else
  HTTP_MSG="curl not available; HTTP check skipped"
fi

if $ACTIVE && $READY; then
  MESSAGE="Service ${SERVICE_NAME} is active and ready"
elif $ACTIVE; then
  MESSAGE="Service ${SERVICE_NAME} is active but not ready: ${HTTP_MSG}"
else
  MESSAGE="Service ${SERVICE_NAME} is not active"
fi

ACTIVE_JSON=$( $ACTIVE && echo true || echo false )
READY_JSON=$( $READY && echo true || echo false )

echo "{\"active\": ${ACTIVE_JSON}, \"ready\": ${READY_JSON}, \"message\": \"${MESSAGE}\"}"
