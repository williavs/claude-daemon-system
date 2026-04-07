#!/usr/bin/env bash
# PostToolUse hook: silently logs every tool call to daily trace file.
# Zero tokens. Pure file append. Invisible to the user.

set -uo pipefail

TRACES_DIR="${HOME}/.claude-daemon/traces"
mkdir -p "$TRACES_DIR"

TRACE_FILE="${TRACES_DIR}/$(date -u +%Y-%m-%d).jsonl"

# Read hook input from stdin
input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // "unknown"' 2>/dev/null)

# Skip read-only tools -- too noisy, no signal
case "$tool_name" in
    Read|Glob|Grep|ToolSearch|SendMessage|TaskGet|TaskList) exit 0 ;;
esac

# Session identity: use CLAUDE_SESSION_ID if available, fall back to parent PID
session="${CLAUDE_SESSION_ID:-${PPID:-unknown}}"

# Project context from cwd
project=$(basename "$CLAUDE_PROJECT_DIR" 2>/dev/null || basename "$(pwd)" 2>/dev/null || echo "unknown")

# Build clean JSON with jq -- no string assembly
echo "$input" | jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg session "$session" \
    --arg project "$project" \
    '{
        ts: $ts,
        session: $session,
        project: $project,
        tool: .tool_name,
        file: (.tool_input.file_path // .tool_input.path // .tool_input.pattern // null),
        cmd: (.tool_input.command // null | if . then (split("\n")[0] | .[0:120]) else null end),
        desc: (.tool_input.description // null)
    } | del(.[] | nulls)' \
    >> "$TRACE_FILE" 2>/dev/null

exit 0
