#!/bin/bash
# Returns the currently installed version of victoria-logs-prod or vlagent-prod.
# Returns {"version": null} if the binary is not found.

set -euo pipefail

COMPONENT="${PT_component:-victorialogs}"

case "$COMPONENT" in
  victorialogs)
    BINARY_PATHS=("/usr/local/bin/victoria-logs-prod" "/usr/bin/victoria-logs-prod")
    ;;
  vlagent)
    BINARY_PATHS=("/usr/local/bin/vlagent-prod" "/usr/bin/vlagent-prod")
    ;;
  *)
    echo "{\"_error\": {\"msg\": \"Unknown component: ${COMPONENT}\", \"kind\": \"victorialogs/unknown-component\", \"details\": {}}}"
    exit 1
    ;;
esac

BINARY=""
for path in "${BINARY_PATHS[@]}"; do
  if [ -x "$path" ]; then
    BINARY="$path"
    break
  fi
done

if [ -z "$BINARY" ]; then
  echo '{"version": null}'
  exit 0
fi

# victoria-logs-prod --version outputs a single line e.g. "victoria-logs-prod-v1.49.0"
RAW=$("$BINARY" --version 2>&1 || true)
VERSION=$(echo "$RAW" | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' || true)

if [ -z "$VERSION" ]; then
  echo '{"version": null}'
else
  echo "{\"version\": \"${VERSION}\"}"
fi
