#!/usr/bin/env bash
# UserPromptSubmit hook: captures what the user asked for.
# This is the most valuable data in the system -- user intent.
# Zero tokens. Append-only.

set -uo pipefail

DAEMON_HOME="${HOME}/.claude-daemon"
PROMPTS_DIR="$DAEMON_HOME/prompts"
mkdir -p "$PROMPTS_DIR"

TODAY=$(date -u +%Y-%m-%d)
PROMPTS_FILE="${PROMPTS_DIR}/${TODAY}.jsonl"

input=$(cat)

# Extract the user's message
prompt_text=$(echo "$input" | jq -r '.prompt // .content // empty' 2>/dev/null)

# Skip empty or very short prompts (just "y" or "ok")
[ ${#prompt_text} -lt 5 ] && exit 0

session="${CLAUDE_SESSION_ID:-${PPID:-unknown}}"
project=$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || echo "unknown")

# Trim to first 500 chars -- enough for intent, not a full paste
trimmed=$(echo "$prompt_text" | head -c 500 | tr '\n' ' ' | sed 's/  */ /g')

jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg session "$session" \
    --arg project "$project" \
    --arg prompt "$trimmed" \
    '{ts: $ts, session: $session, project: $project, prompt: $prompt}' \
    >> "$PROMPTS_FILE" 2>/dev/null

exit 0
