#!/usr/bin/env bash
# PreCompact hook: re-inject persist mode goal if active for THIS session.
# Nothing else. Identity comes from peers. Context comes from CLAUDE.md.
set -uo pipefail

PERSIST_GOAL="${HOME}/.claude-daemon/state/persist-goal.md"
PERSIST_SESSION="${HOME}/.claude-daemon/state/persist-session"

# Not in persist mode? Nothing to inject.
[ -f "$PERSIST_GOAL" ] || exit 0

# Read session_id from stdin
input=""
read -t 1 -r input 2>/dev/null || true
session_id=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")

# Only inject for the session that activated persist mode
if [ -f "$PERSIST_SESSION" ]; then
    persist_session=$(cat "$PERSIST_SESSION")
    [ "$persist_session" != "any" ] && [ "$persist_session" != "$session_id" ] && exit 0
fi

goal=$(cat "$PERSIST_GOAL")
printf '{"systemMessage": "PERSIST MODE ACTIVE after compaction. Goal: %s. Continue working."}\n' "$goal"

exit 0
