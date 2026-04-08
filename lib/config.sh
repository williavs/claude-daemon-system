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

# ── LiteLLM routing ──
# When litellm.enabled is true, export env vars so claude -p routes through
# the LiteLLM proxy to gemini-3-flash instead of hitting Anthropic directly.
# This gives us ~6x cheaper calls AND lets us bump budgets without burning money.
LITELLM_ENABLED=$(cfg_bool '.litellm.enabled')
LITELLM_URL=$(cfg '.litellm.url')
LITELLM_KEY=$(cfg '.litellm.key')
LITELLM_MODEL=$(cfg '.litellm.model // "gemini-3-flash"')

if [ "$LITELLM_ENABLED" = "true" ] && [ -n "$LITELLM_URL" ] && [ -n "$LITELLM_KEY" ]; then
    export ANTHROPIC_BASE_URL="$LITELLM_URL"
    export ANTHROPIC_AUTH_TOKEN="$LITELLM_KEY"
fi

# Helper: return the model to use for claude -p calls.
# When LiteLLM is on, returns gemini-3-flash regardless of the shortname passed.
# When off, maps shortnames (haiku/sonnet/opus) to full Claude model IDs.
resolve_model() {
    local shortname="${1:-sonnet}"
    if [ "$LITELLM_ENABLED" = "true" ]; then
        echo "$LITELLM_MODEL"
        return
    fi
    case "$shortname" in
        haiku)  echo "claude-haiku-4-5" ;;
        sonnet) echo "claude-sonnet-4-6" ;;
        opus)   echo "claude-opus-4-6" ;;
        *)      echo "$shortname" ;;
    esac
}
