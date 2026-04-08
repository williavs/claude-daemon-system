#!/usr/bin/env bash
# Install health reporter on macOS (uses launchd instead of systemd)
set -euo pipefail

SCRIPT_DIR="$HOME/.fleet-reporter"
mkdir -p "$SCRIPT_DIR"

cat > "$SCRIPT_DIR/report.sh" << 'REPORTER'
#!/usr/bin/env bash
set -uo pipefail
MACHINE=$(tailscale status --self --json 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin).get('Self',{}).get('DNSName','unknown').split('.')[0])" 2>/dev/null || hostname -s)
{
  echo "=== $MACHINE $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  df -h /
  vm_stat | head -10
  uptime
  ps aux --sort=-%mem 2>/dev/null | head -8 || ps aux | sort -k4 -rn | head -8
  who
} > /tmp/health-report.txt 2>&1
scp -q /tmp/health-report.txt "your-homelab:~/.fleet-health/${MACHINE}.txt" 2>/dev/null
REPORTER
chmod +x "$SCRIPT_DIR/report.sh"

# launchd plist
cat > ~/Library/LaunchAgents/com.fleet-health.reporter.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fleet-health.reporter</string>
    <key>ProgramArguments</key>
    <array>
        <string>${SCRIPT_DIR}/report.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.fleet-health.reporter.plist 2>/dev/null
echo "Installed on $(hostname -s). Reporting every 5 min to your-homelab."
