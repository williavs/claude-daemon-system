#!/usr/bin/env bash
# PostCompact hook: logs the compact summary and checks what survived.
# Fires after compaction completes. The compact_summary field contains
# what the compaction preserved. We log it for the meta-agent to review.
set -uo pipefail

DAEMON_HOME="${HOME}/.claude-daemon"
mkdir -p "$DAEMON_HOME/logs"

input=$(cat)

trigger=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('trigger','unknown'))" 2>/dev/null)
summary=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('compact_summary','')[:2000])" 2>/dev/null)
session_id=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)

# Log compaction event with summary length
printf '{"ts":"%s","action":"compaction","trigger":"%s","session":"%s","summary_len":%d}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$trigger" "$session_id" "${#summary}" \
    >> "$DAEMON_HOME/logs/activity.jsonl" 2>/dev/null

# Save the summary for meta-agent review (what survived compaction?)
if [ -n "$summary" ]; then
    python3 -c "
import json, sys
print(json.dumps({
    'ts': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'trigger': '$trigger',
    'session': '$session_id',
    'summary': sys.stdin.read().strip()
}))
" <<< "$summary" >> "$DAEMON_HOME/logs/compactions.jsonl" 2>/dev/null
fi

exit 0
