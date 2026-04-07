#!/usr/bin/env bash
# PostToolUseFailure hook: captures tool failures as lessons.
# Currently only daemon tasks write to lessons.md -- this hook
# catches failures from ALL sessions (interactive + daemon).
# Async so it never blocks Claude.
set -uo pipefail

DAEMON_HOME="${HOME}/.claude-daemon"
LESSONS="$DAEMON_HOME/logs/lessons.md"
mkdir -p "$(dirname "$LESSONS")"

input=$(cat)

tool_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name','unknown'))" 2>/dev/null)
error=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','unknown')[:200])" 2>/dev/null)
is_interrupt=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('is_interrupt',False))" 2>/dev/null)

# Skip user interrupts -- not real failures
[ "$is_interrupt" = "True" ] && exit 0

# Skip common noise: file not found, permission denied on Read (normal exploration)
case "$error" in
    *"No such file"*|*"ENOENT"*|*"not found"*) exit 0 ;;
    *"Permission denied"*) exit 0 ;;
esac

# Extract command if Bash tool
cmd=""
if [ "$tool_name" = "Bash" ]; then
    cmd=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command','')[:120])" 2>/dev/null)
fi

project=$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || echo "unknown")

# Append to lessons -- lightweight, just the facts
printf '\n### %s | %s failure in %s\n- Tool: %s%s\n- Error: %s\n\n' \
    "$(date +%Y-%m-%d)" "$tool_name" "$project" \
    "$tool_name" \
    "$([ -n "$cmd" ] && echo " ($cmd)" || echo "")" \
    "$error" \
    >> "$LESSONS" 2>/dev/null

exit 0
