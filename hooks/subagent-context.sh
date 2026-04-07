#!/usr/bin/env bash
# SubagentStart hook: injects cached design decisions into every subagent.
# The heavy lifting (haiku extraction) is done by extract-decisions.sh
# running async on UserPromptSubmit. This hook just reads the cache.
# ~0.08s execution time.
set -uo pipefail

input=$(cat)

session_id=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
cwd=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)

CACHE_FILE="${HOME}/.claude-daemon/state/subagent-decisions-${session_id}.txt"

# Read cached decisions (populated by extract-decisions.sh on each prompt)
if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
    python3 -c "
import json, sys
context = sys.stdin.read().strip()
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SubagentStart',
        'additionalContext': context
    }
}))
" < "$CACHE_FILE"
    exit 0
fi

# No cache yet -- fallback to CLAUDE.md reminder
if [ -f "$cwd/CLAUDE.md" ]; then
    python3 -c "
import json
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SubagentStart',
        'additionalContext': 'Read $cwd/CLAUDE.md before making any design decisions.'
    }
}))
"
fi

exit 0
