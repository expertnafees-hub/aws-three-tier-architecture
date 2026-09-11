#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# chaos_test.sh — Automated Probe & Self-Healing Monitor
# -----------------------------------------------------------------------------
# Safely monitors ALB availability and demonstrates ASG self-healing during
# intentional instance termination drills.
# -----------------------------------------------------------------------------

set -euo pipefail

echo "======================================================================"
echo " 🧪 AWS 3-TIER ARCHITECTURE: ASG SELF-HEALING & CHAOS RECOVERY PROBE"
echo "======================================================================"

# 1. Fetch ALB Endpoint
if command -v terraform >/dev/null 2>&1 && [ -f "outputs.tf" ]; then
  ALB_URL=$(terraform output -raw alb_public_dns 2>/dev/null || echo "")
else
  ALB_URL=""
fi

if [ -z "$ALB_URL" ]; then
  read -rp "Enter Application Load Balancer URL (e.g. http://three-tier-prod-alb-...elb.amazonaws.com): " ALB_URL
fi

echo "Target Endpoint: $ALB_URL"
echo "Starting continuous HTTP health probe (Press Ctrl+C to stop)..."
echo "----------------------------------------------------------------------"
printf "%-10s | %-12s | %-15s | %s\n" "TIME" "HTTP STATUS" "AVAILABILITY ZONE" "INSTANCE ID"
echo "----------------------------------------------------------------------"

COUNT=0
DROPPED=0

trap 'echo ""; echo "=== SUMMARY ==="; echo "Total Probes: $COUNT"; echo "Dropped/Failed: $DROPPED"; exit 0' INT

while true; do
  TIME=$(date +'%T')
  RESP=$(curl -s -m 2 "$ALB_URL" || echo "")
  STATUS=$(curl -s -m 2 -o /dev/null -w "%{http_code}" "$ALB_URL" || echo "000")
  
  if [ "$STATUS" = "200" ]; then
    AZ=$(echo "$RESP" | grep -o 'us-east-1[a-z]' | head -1 || echo "unknown")
    IID=$(echo "$RESP" | grep -o 'i-[0-9a-f]\{8,17\}' | head -1 || echo "unknown")
    printf "%-10s | \033[32m%-12s\033[0m | %-15s | %s\n" "$TIME" "200 OK" "$AZ" "$IID"
  else
    DROPPED=$((DROPPED + 1))
    printf "%-10s | \033[31m%-12s\033[0m | %-15s | %s\n" "$TIME" "$STATUS" "DOWN/TIMEOUT" "NONE"
  fi
  
  COUNT=$((COUNT + 1))
  sleep 1
done
