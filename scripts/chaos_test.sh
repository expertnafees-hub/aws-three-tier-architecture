#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# chaos_test.sh — HTTP probe for controlled ASG/ALB failure testing
# -----------------------------------------------------------------------------
# This script records observed availability during a test. It does not claim or
# prove universal zero downtime.
# -----------------------------------------------------------------------------

set -euo pipefail

TMP_BODY=$(mktemp)
cleanup() {
  rm -f "$TMP_BODY"
}
trap cleanup EXIT

echo "======================================================================"
echo " AWS 3-TIER ARCHITECTURE: CONTROLLED AVAILABILITY PROBE"
echo "======================================================================"

if command -v terraform >/dev/null 2>&1 && [ -f "outputs.tf" ]; then
  APP_URL=$(terraform output -raw application_url 2>/dev/null || true)
else
  APP_URL=""
fi

if [ -z "$APP_URL" ]; then
  read -rp "Enter application URL (HTTP or HTTPS): " APP_URL
fi

echo "Target Endpoint: $APP_URL"
echo "Starting serial probes with a one-second pause after each request (Press Ctrl+C to stop)..."
echo "----------------------------------------------------------------------"
printf "%-10s | %-12s | %-15s | %s\n" "TIME" "HTTP STATUS" "AVAILABILITY ZONE" "INSTANCE ID"
echo "----------------------------------------------------------------------"

COUNT=0
FAILED=0

summary() {
  echo ""
  echo "=== SUMMARY ==="
  echo "Total Probes: $COUNT"
  echo "Failed/Non-200: $FAILED"
}
trap 'summary; exit 0' INT TERM

while true; do
  TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

  # Capture body and status from the SAME request so backend metadata and status
  # cannot come from different load-balanced targets.
  : > "$TMP_BODY"
  if ! STATUS=$(curl --max-time 5 -sS -o "$TMP_BODY" -w "%{http_code}" "$APP_URL" 2>/dev/null); then
    STATUS="000"
  fi
  RESP=$(cat "$TMP_BODY" 2>/dev/null || true)

  if [ "$STATUS" = "200" ]; then
    AZ=$(printf '%s' "$RESP" | grep -Eo '[a-z]{2}(-[a-z]+)+-[0-9]+[a-z]' | head -1 || true)
    IID=$(printf '%s' "$RESP" | grep -o 'i-[0-9a-f]\{8,17\}' | head -1 || true)
    AZ=${AZ:-unknown}
    IID=${IID:-unknown}
    printf "%-10s | \033[32m%-12s\033[0m | %-15s | %s\n" "$TIME" "200 OK" "$AZ" "$IID"
  else
    FAILED=$((FAILED + 1))
    printf "%-10s | \033[31m%-12s\033[0m | %-15s | %s\n" "$TIME" "$STATUS" "UNAVAILABLE" "NONE"
  fi

  COUNT=$((COUNT + 1))
  sleep 1
done
