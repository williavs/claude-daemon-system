#!/usr/bin/env bash
# Auto-enroll ALL Tailscale machines into fleet health reporting.
# Works for Linux (systemd), macOS (launchd), any SSH-able machine.
# Runs as a daemon task. Plug a new Pi into Tailscale, it gets monitoring.
set -uo pipefail
# Not using -e: pipe patterns (tail|grep, wc) trigger SIGPIPE with pipefail

DAEMON_HOME="${CLAUDE_DAEMON_HOME:-$HOME/.claude-daemon}"
FLEET_DIR="$HOME/projects/claude-daemon/fleet"
ENROLLED_FILE="$DAEMON_HOME/state/enrolled-machines.txt"
touch "$ENROLLED_FILE"

# Get ALL machines from Tailscale that aren't offline or iOS
while read -r ip name user os status; do
    # Skip iOS (can't SSH), skip offline
    [[ "$os" == "iOS" ]] && continue
    echo "$status" | grep -q "offline" && continue
    # Skip self
    [[ "$name" == "$(hostname)" ]] && continue
    # Skip if already enrolled
    grep -qxF "$name" "$ENROLLED_FILE" && continue

    echo "[auto-enroll] Detected: $name ($os)"

    # Test SSH (2s timeout, batch mode)
    if ! ssh -o ConnectTimeout=2 -o BatchMode=yes "$name" "echo ok" &>/dev/null; then
        echo "[auto-enroll] $name: SSH failed, skipping (will retry next run)"
        continue
    fi

    # Detect OS on remote and pick the right installer
    remote_os=$(ssh -o ConnectTimeout=5 "$name" "uname -s" 2>/dev/null || echo "unknown")

    case "$remote_os" in
        Linux)
            # Check if already installed
            if ssh "$name" "systemctl --user is-active fleet-health.timer" &>/dev/null; then
                echo "[auto-enroll] $name: already reporting (Linux)"
                echo "$name" >> "$ENROLLED_FILE"
                continue
            fi
            echo "[auto-enroll] $name: installing Linux reporter..."
            scp -q "$FLEET_DIR/install-reporter.sh" "$name:~/install-reporter.sh" && \
            ssh "$name" "bash ~/install-reporter.sh && rm ~/install-reporter.sh"
            ;;
        Darwin)
            # Check if already installed
            if ssh "$name" "launchctl list com.fleet-health.reporter" &>/dev/null; then
                echo "[auto-enroll] $name: already reporting (macOS)"
                echo "$name" >> "$ENROLLED_FILE"
                continue
            fi
            echo "[auto-enroll] $name: installing macOS reporter..."
            scp -q "$FLEET_DIR/install-reporter-macos.sh" "$name:~/install-reporter.sh" && \
            ssh "$name" "bash ~/install-reporter.sh && rm ~/install-reporter.sh"
            ;;
        *)
            echo "[auto-enroll] $name: unknown OS ($remote_os), skipping"
            continue
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo "$name" >> "$ENROLLED_FILE"
        echo "[auto-enroll] $name: enrolled ($remote_os)"
    else
        echo "[auto-enroll] $name: install failed"
    fi
done < <(tailscale status 2>/dev/null | tail -n +1 | grep -v "^#\|^$")

# Summary
total=$(wc -l < "$ENROLLED_FILE")
reporting=$(ssh "${FLEET_HEALTH_DEST:-your-homelab}" "ls ~/.fleet-health/*.txt 2>/dev/null | wc -l" 2>/dev/null || echo "?")
echo "[auto-enroll] Fleet: $total enrolled, $reporting actively reporting"
