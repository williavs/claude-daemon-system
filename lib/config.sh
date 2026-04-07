#!/usr/bin/env bash
# Shared config loader for all cd-* scripts.
# Source this: source "$(dirname "$0")/../lib/config.sh"
#
# Provides:
#   $DAEMON_HOME    -- resolved daemon home dir
#   $CONFIG         -- path to config.json
#   cfg()           -- read a config value: cfg '.email.recipients'
#   cfg_bool()      -- read a boolean: cfg_bool '.fleet.enabled'

DAEMON_HOME="${CLAUDE_DAEMON_HOME:-$HOME/.claude-daemon}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${DAEMON_HOME}/config.json"

# Fallback: if config.json doesn't exist, copy template
if [ ! -f "$CONFIG" ]; then
    if [ -f "$SCRIPT_DIR/config.template.json" ]; then
        cp "$SCRIPT_DIR/config.template.json" "$CONFIG"
        echo "Created $CONFIG from template. Edit it with your settings." >&2
    else
        echo "No config.json found at $CONFIG" >&2
        exit 1
    fi
fi

# Read a config value. Returns empty string if not found.
cfg() {
    jq -r "$1 // empty" "$CONFIG" 2>/dev/null
}

# Read a boolean config value. Returns "true" or "false".
cfg_bool() {
    jq -r "$1 // false" "$CONFIG" 2>/dev/null
}

# Common directories
TASKS_DIR="$DAEMON_HOME/tasks"
LOGS_DIR="$DAEMON_HOME/logs"
STATE_DIR="$DAEMON_HOME/state"

mkdir -p "$TASKS_DIR" "$LOGS_DIR" "$STATE_DIR"
