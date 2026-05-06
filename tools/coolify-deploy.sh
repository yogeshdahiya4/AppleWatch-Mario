#!/usr/bin/env bash
# Trigger a Coolify deploy for the PixelHop backend.
# REQUIRED because pushes to GitHub do NOT auto-deploy on this Coolify setup.
# Polls deployment status until finished or failed.
set -euo pipefail

TOKEN=$(<"$HOME/.coolify-token")
BASE="http://72.62.0.34:8000"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UUID_FILE="$REPO_ROOT/.coolify-uuids.json"

if [[ ! -f "$UUID_FILE" ]]; then
  echo "ERROR: $UUID_FILE not found. Run tools/coolify-bootstrap.sh first." >&2
  exit 1
fi

APP_UUID=$(jq -r '.app' "$UUID_FILE")
if [[ -z "$APP_UUID" || "$APP_UUID" == "null" ]]; then
  echo "ERROR: app uuid not in $UUID_FILE." >&2
  exit 1
fi

echo "==> Triggering deploy for app $APP_UUID"
DEPLOY=$(curl -fsS -H "Authorization: Bearer $TOKEN" \
  "$BASE/api/v1/deploy?uuid=$APP_UUID&force=true")
DEPLOY_UUID=$(echo "$DEPLOY" | jq -r '.deployments[0].deployment_uuid // .deployment_uuid // empty')
echo "    deployment uuid: ${DEPLOY_UUID:-(unknown — older Coolify)}"

echo "==> Polling status..."
for i in $(seq 1 120); do
  STATUS_JSON=$(curl -fsS -H "Authorization: Bearer $TOKEN" \
    "$BASE/api/v1/deployments")
  if [[ -n "$DEPLOY_UUID" ]]; then
    LINE=$(echo "$STATUS_JSON" | jq -r --arg u "$DEPLOY_UUID" \
      '.[] | select(.deployment_uuid==$u or .id==$u) | "\(.status)\t\(.commit // "?" | .[0:8])"' | head -1)
  else
    LINE=$(echo "$STATUS_JSON" | jq -r --arg u "$APP_UUID" \
      '.[] | select(.application_uuid==$u) | "\(.status)\t\(.commit // "?" | .[0:8])"' | head -1)
  fi
  if [[ -z "$LINE" ]]; then
    echo "  [$i] (no status row yet)"; sleep 5; continue
  fi
  STATUS="${LINE%%	*}"
  echo "  [$i] $LINE"
  case "$STATUS" in
    finished|success) echo "==> ✓ deploy finished"; exit 0 ;;
    failed|error|cancelled) echo "==> ✗ deploy $STATUS"; exit 1 ;;
  esac
  sleep 5
done

echo "==> timed out waiting for deploy"
exit 2
