#!/usr/bin/env bash
# StopFailure hook: logs API errors and alerts on rate limits.
# Fires when a turn ends due to an API error instead of normal completion.
# Critical for catching daemon failures at 3am.
set -uo pipefail

DAEMON_HOME="${HOME}/.claude-daemon"
input=$(cat)

error_type=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','unknown'))" 2>/dev/null || echo "unknown")
error_details=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error_details','')[:200])" 2>/dev/null || echo "")
session_id=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")

# Log to errors.jsonl
printf '{"ts":"%s","error_type":"%s","details":"%s","session":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$error_type" "$error_details" "$session_id" \
    >> "$DAEMON_HOME/logs/errors.jsonl" 2>/dev/null

# Desktop notification for rate limits (the one that kills daemon runs)
if [ "$error_type" = "rate_limit" ]; then
    notify-send "Claude Code: Rate Limited" "$error_details" 2>/dev/null || true
fi

exit 0
