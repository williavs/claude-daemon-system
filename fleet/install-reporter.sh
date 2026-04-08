#!/usr/bin/env bash
# Run this ON a fleet machine to install the health reporter.
# Usage: curl -s <raw-url> | bash
#    or: scp install-reporter.sh machine: && ssh machine bash install-reporter.sh
set -euo pipefail

SCRIPT_DIR="$HOME/.fleet-reporter"
mkdir -p "$SCRIPT_DIR"

# Write the reporter script
cat > "$SCRIPT_DIR/report.sh" << 'REPORTER'
#!/usr/bin/env bash
set -uo pipefail
MACHINE=$(hostname)
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
if [ "$MACHINE" = "your-homelab" ]; then
    mkdir -p ~/.fleet-health
    cp /tmp/health-report.txt ~/.fleet-health/${MACHINE}.txt
else
    scp -q /tmp/health-report.txt "your-homelab:~/.fleet-health/${MACHINE}.txt" 2>/dev/null
fi
REPORTER
chmod +x "$SCRIPT_DIR/report.sh"

# Install systemd timer
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/fleet-health.service << EOF
[Unit]
Description=Fleet health reporter

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/report.sh
EOF

cat > ~/.config/systemd/user/fleet-health.timer << 'EOF'
[Unit]
Description=Report health every 5 minutes

[Timer]
OnBootSec=30
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now fleet-health.timer

echo "Installed on $(hostname). Reporting every 5 min to your-homelab:~/.fleet-health/"
