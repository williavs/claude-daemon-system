#!/usr/bin/env bash
# Stop hook: blocks stop if there's unfinished work in persist mode.
# Session-isolated, circuit-breaker protected, uses last_assistant_message
# to detect if Claude believes the goal is complete.
#
# Input (stdin JSON): stop_hook_active, last_assistant_message, session_id, transcript_path
# Output: {"decision":"block","reason":"..."} to prevent stopping

set -uo pipefail

DAEMON_HOME="${HOME}/.claude-daemon"
STATE_DIR="$DAEMON_HOME/state"
GOAL_FILE="$STATE_DIR/persist-goal.md"
LOOP_FILE="$STATE_DIR/persist-loops"
SESSION_FILE="$STATE_DIR/persist-session"
MAX_LOOPS=10

# Not in persist mode? Let Claude stop normally.
[ -f "$GOAL_FILE" ] || exit 0

# Read stdin for hook context
input=$(cat)

# Session isolation: only block the session that activated persist mode.
if [ -f "$SESSION_FILE" ]; then
    persist_session=$(cat "$SESSION_FILE")
    current_session=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','unknown'))" 2>/dev/null || echo "${CLAUDE_SESSION_ID:-${PPID:-unknown}}")
    if [ "$persist_session" != "any" ] && [ "$persist_session" != "$current_session" ]; then
        exit 0
    fi
fi

# Check stop_hook_active -- if already in a continuation loop, use circuit breaker
stop_active=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null || echo "False")

# Circuit breaker: count loops, halt after MAX_LOOPS
loops=$(cat "$LOOP_FILE" 2>/dev/null || echo 0)
loops=$((loops + 1))
tmp=$(mktemp "$STATE_DIR/tmp.XXXXXX" 2>/dev/null || echo "$LOOP_FILE.tmp")
echo "$loops" > "$tmp" && mv "$tmp" "$LOOP_FILE"

if [ "$loops" -ge "$MAX_LOOPS" ]; then
    rm -f "$GOAL_FILE" "$LOOP_FILE" "$SESSION_FILE"
    printf '{"ts":"%s","action":"persist_maxed","loops":%d}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$loops" \
        >> "$DAEMON_HOME/logs/activity.jsonl"
    exit 0
fi

goal=$(cat "$GOAL_FILE")

# Extract Claude's last message -- did it say the goal is complete?
last_msg=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('last_assistant_message','')[:500])" 2>/dev/null || echo "")

# Block the stop with goal + Claude's last message for context
python3 -c "
import json, sys

goal = '''$goal'''
last_msg = sys.stdin.read().strip()
loops = $loops
max_loops = $MAX_LOOPS

reason = f'''PERSIST MODE (loop {loops}/{max_loops}): Your goal is not yet complete.

GOAL: {goal}

YOUR LAST MESSAGE (what you just said):
{last_msg[:300] if last_msg else 'No message captured.'}

INSTRUCTIONS: Compare your last message against the goal. If you made progress, continue with the next sub-task. If you believe the goal IS fully complete, tell the user explicitly and they will run: cd-persist off'''

print(json.dumps({'decision': 'block', 'reason': reason}))
" <<< "$last_msg"
