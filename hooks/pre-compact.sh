#!/usr/bin/env bash
# PreCompact hook: re-inject critical context before compression.
# Ensures session coherence survives compaction.
#
# Reads stdin: {"trigger":"manual"|"auto","custom_instructions":"..."}
# Outputs: {"systemMessage":"..."} to inject context post-compaction.

set -uo pipefail

HANDOFF="${HOME}/.claude-daemon/state/session-handoff.md"
PERSIST_GOAL="${HOME}/.claude-daemon/state/persist-goal.md"

# Read stdin for compaction context
input=""
read -t 1 -r input 2>/dev/null || true
trigger=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('trigger','unknown'))" 2>/dev/null || echo "unknown")

# Build the system message
msg="CONTEXT RESTORED ($trigger compaction): You are Jim. You manage the claude-daemon system."

if [ -f "$HANDOFF" ] && [ -s "$HANDOFF" ]; then
    msg="$msg After compaction, read ~/.claude-daemon/state/session-handoff.md for full context."
fi

if [ -f "$PERSIST_GOAL" ] && [ -s "$PERSIST_GOAL" ]; then
    goal=$(cat "$PERSIST_GOAL")
    msg="$msg PERSIST MODE ACTIVE -- goal: $goal. Continue working, do NOT stop."
fi

msg="$msg Key: effective-go plugin shipped, effective-claude skill V2, daemon with nightly opus meta-agent at 3am, 5 fleet machines reporting, persist mode validated."

# Escape for JSON
msg=$(echo "$msg" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null)

printf '{"systemMessage": %s}\n' "$msg"

exit 0
