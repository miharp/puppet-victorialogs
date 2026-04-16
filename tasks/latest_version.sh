#!/bin/bash
# Queries the GitHub releases API and returns the latest VictoriaLogs release tag.
# Safe to run on the Bolt controller: run_task('victorialogs::latest_version', 'localhost')

set -euo pipefail

COMPONENT="${PT_component:-victorialogs}"

case "$COMPONENT" in
  victorialogs)
    REPO="VictoriaMetrics/VictoriaLogs"
    ;;
  vlagent)
    REPO="VictoriaMetrics/VictoriaLogs"
    ;;
  *)
    echo "{\"_error\": {\"msg\": \"Unknown component: ${COMPONENT}\", \"kind\": \"victorialogs/unknown-component\", \"details\": {}}}"
    exit 1
    ;;
esac

API_URL="https://api.github.com/repos/${REPO}/releases/latest"

if command -v curl &>/dev/null; then
  RESPONSE=$(curl -sf \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$API_URL")
else
  echo '{"_error": {"msg": "curl is required but not found", "kind": "victorialogs/missing-dependency", "details": {}}}'
  exit 1
fi

# Extract tag_name from the JSON response using sed (no jq dependency required)
TAG=$(echo "$RESPONSE" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')

if [ -z "$TAG" ]; then
  echo '{"_error": {"msg": "Could not determine latest version from GitHub API", "kind": "victorialogs/api-error", "details": {}}}'
  exit 1
fi

# Strip leading 'v' if present so callers get a bare version string
VERSION="${TAG#v}"

echo "{\"version\": \"${VERSION}\"}"
