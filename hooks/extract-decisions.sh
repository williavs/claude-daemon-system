#!/usr/bin/env bash
# UserPromptSubmit hook (async): extracts design decisions from the conversation
# and caches them for the SubagentStart hook. Runs in background after every prompt
# so the cache is always warm when a subagent spawns.
set -uo pipefail

input=$(cat)

session_id=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
transcript_path=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)
cwd=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)
prompt=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('prompt','')[:100])" 2>/dev/null)

CACHE_DIR="${HOME}/.claude-daemon/state"
CACHE_FILE="$CACHE_DIR/subagent-decisions-${session_id}.txt"
mkdir -p "$CACHE_DIR"

# Skip short prompts (just "y", "ok", "continue")
[ ${#prompt} -lt 15 ] && exit 0

# Skip if transcript doesn't exist
[ -z "$transcript_path" ] || [ ! -f "$transcript_path" ] && exit 0

# Extract recent user messages
recent=$(python3 -c "
import json
messages = []
try:
    with open('$transcript_path') as f:
        for line in f:
            try:
                msg = json.loads(line.strip())
                role = msg.get('message', {}).get('role', '')
                if role == 'user':
                    content = msg.get('message', {}).get('content', '')
                    if isinstance(content, str) and len(content) > 10:
                        messages.append(content[:150])
                    elif isinstance(content, list):
                        for block in content:
                            if isinstance(block, dict) and block.get('type') == 'text':
                                text = block.get('text', '')
                                if len(text) > 10:
                                    messages.append(text[:150])
            except: pass
except: pass
for m in messages[-10:]:
    print(m)
" 2>/dev/null)

[ -z "$recent" ] || [ ${#recent} -lt 20 ] && exit 0

# Haiku extracts decisions
decisions=$(claude -p "Extract ONLY design decisions and constraints from these user messages. Short bullet list. If none, say NONE.

Messages:
$recent" \
    --model claude-haiku-4-5 \
    --max-turns 2 \
    --output-format text \
    --dangerously-skip-permissions \
    2>/dev/null)

if [ -n "$decisions" ] && ! echo "$decisions" | grep -qi "^NONE"; then
    context="DESIGN DECISIONS FROM THIS SESSION (follow these):
$decisions"
    [ -f "$cwd/CLAUDE.md" ] && context="$context
Also read $cwd/CLAUDE.md for project-level rules."
    echo "$context" > "$CACHE_FILE"
fi

exit 0
