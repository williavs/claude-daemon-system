#!/usr/bin/env bash
# Runs on each fleet machine via systemd timer. Dumps full state to your-homelab.
# No filtering, no thresholds -- just raw state. The daemon interprets it.
set -uo pipefail

MACHINE=$(hostname)
# DEST is set by the install script or overridden by env var
DEST="${FLEET_HEALTH_DEST:-your-homelab}"
DEST_DIR=".fleet-health"

{
  echo "=== $MACHINE $(date -Iseconds) ==="
  df -h /
  free -h
  uptime
  systemctl --failed --no-pager 2>/dev/null || true
  journalctl --priority=err --since="10 min ago" --no-pager -q 2>/dev/null | tail -20 || true
  ss -tlnp 2>/dev/null | head -15 || true
  ps aux --sort=-%mem 2>/dev/null | head -8 || true
  who 2>/dev/null || true
} > /tmp/health-report.txt 2>&1

# If we ARE the destination, just copy locally
if [ "$MACHINE" = "$DEST" ] || [ "$MACHINE" = "your-homelab" ]; then
    mkdir -p ~/${DEST_DIR}
    cp /tmp/health-report.txt ~/${DEST_DIR}/${MACHINE}.txt
else
    scp -q /tmp/health-report.txt "${DEST}:~/${DEST_DIR}/${MACHINE}.txt" 2>/dev/null
fi
