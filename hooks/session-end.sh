#!/usr/bin/env bash
# SessionEnd hook: distills the entire session into a digest.
# This is what the meta-agent actually reads -- not raw traces.
# Runs async on session end.

set -uo pipefail

DAEMON_HOME="${HOME}/.claude-daemon"
DIGESTS_FILE="$DAEMON_HOME/logs/digests.jsonl"
mkdir -p "$(dirname "$DIGESTS_FILE")"

TODAY=$(date -u +%Y-%m-%d)
SESSION="${CLAUDE_SESSION_ID:-${PPID:-unknown}}"
PROJECT=$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || echo "unknown")

# Count actions from today's traces for this session
# Use python3 for JSON parsing (jq not guaranteed on all machines)
TRACE_FILE="$DAEMON_HOME/traces/${TODAY}.jsonl"
edits=0; bash_calls=0; agents=0; writes=0
if [ -f "$TRACE_FILE" ]; then
    # Count by grepping for session -- handles both exact and partial matches
    edits=$(grep -c "\"tool\":\"Edit\"" "$TRACE_FILE" 2>/dev/null || echo 0)
    writes=$(grep -c "\"tool\":\"Write\"" "$TRACE_FILE" 2>/dev/null || echo 0)
    bash_calls=$(grep -c "\"tool\":\"Bash\"" "$TRACE_FILE" 2>/dev/null || echo 0)
    agents=$(grep -c "\"tool\":\"Agent\"" "$TRACE_FILE" 2>/dev/null || echo 0)
fi

# Collect this session's prompts
PROMPTS_FILE="$DAEMON_HOME/prompts/${TODAY}.jsonl"
prompts="[]"
if [ -f "$PROMPTS_FILE" ]; then
    # Extract prompts, using python3 for reliable JSON handling
    prompts=$(python3 -c "
import json, sys
results = []
for line in open('$PROMPTS_FILE'):
    try:
        d = json.loads(line.strip())
        p = d.get('prompt', '')
        if p and len(p) > 10:
            results.append(p[:150])
    except: pass
# Take last 10 prompts (most recent session activity)
print(json.dumps(results[-10:]))
" 2>/dev/null || echo "[]")
fi

# Collect unique files touched (from traces)
files="[]"
if [ -f "$TRACE_FILE" ]; then
    files=$(python3 -c "
import json
seen = set()
for line in open('$TRACE_FILE'):
    try:
        d = json.loads(line.strip())
        f = d.get('file')
        if f: seen.add(f)
    except: pass
print(json.dumps(sorted(seen)[:20]))
" 2>/dev/null || echo "[]")
fi

# Build the digest using python3 for clean JSON output
python3 -c "
import json, sys
digest = {
    'ts': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'session': '$SESSION',
    'project': '$PROJECT',
    'actions': {'edits': $((edits + writes)), 'bash': $bash_calls, 'agents': $agents},
    'asked': $prompts,
    'files_touched': $files
}
print(json.dumps(digest))
" >> "$DIGESTS_FILE" 2>/dev/null

exit 0
