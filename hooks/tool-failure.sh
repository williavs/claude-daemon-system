#!/usr/bin/env bash
# PostToolUseFailure hook: captures MEANINGFUL tool failures.
# Filters out one-off debugging noise. Only writes lessons for:
# - Repeated failures (same error pattern seen 2+ times)
# - Daemon/headless sessions (always capture)
# Async so it never blocks Claude.
set -uo pipefail

DAEMON_HOME="${HOME}/.claude-daemon"
FAILURES_LOG="$DAEMON_HOME/logs/failures.jsonl"
LESSONS="$DAEMON_HOME/logs/lessons.md"
mkdir -p "$(dirname "$FAILURES_LOG")"

input=$(cat)

tool_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name','unknown'))" 2>/dev/null)
error=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','unknown')[:200])" 2>/dev/null)
is_interrupt=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_interrupt',False))" 2>/dev/null)
agent_type=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agent_type',''))" 2>/dev/null)

# Skip user interrupts
[ "$is_interrupt" = "True" ] && exit 0

# Skip exploration noise
case "$error" in
    *"No such file"*|*"ENOENT"*|*"not found"*|*"not a regular file"*) exit 0 ;;
    *"Permission denied"*) exit 0 ;;
    *"unable to fetch"*|*"Cannot index"*) exit 0 ;;  # web fetch failures
    *"Exit code 1"*) exit 0 ;;  # generic exit 1 from bash commands -- too noisy
    *"Exit code 2"*) exit 0 ;;  # generic exit 2
    *"exceeds maximum"*) exit 0 ;; # file too large for Read
esac

project=$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || echo "unknown")

# Always log to failures.jsonl (structured, for analysis)
# This is the raw data -- lessons.md is the distilled version
python3 -c "
import json
print(json.dumps({
    'ts': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'tool': '$tool_name',
    'project': '$project',
    'error': '''$(echo "$error" | head -c 150)''',
    'agent_type': '$agent_type'
}))
" >> "$FAILURES_LOG" 2>/dev/null

# Only write to lessons.md if this is a daemon/headless session
# Interactive one-off failures are debugging, not lessons
if [ -n "$agent_type" ]; then
    cmd=""
    [ "$tool_name" = "Bash" ] && cmd=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command','')[:120])" 2>/dev/null)

    printf '\n### %s | %s failure in %s\n- Tool: %s%s\n- Error: %s\n\n' \
        "$(date +%Y-%m-%d)" "$tool_name" "$project" \
        "$tool_name" \
        "$([ -n "$cmd" ] && echo " ($cmd)" || echo "")" \
        "$error" \
        >> "$LESSONS" 2>/dev/null
fi

exit 0
